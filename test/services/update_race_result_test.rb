require "test_helper"
require "minitest/mock"

class UpdateRaceResultTest < ActiveSupport::TestCase
  # melbourne_2026 has no race_results — use it for fresh inserts.
  setup do
    @race = races(:melbourne_2026)
    @verstappen = drivers(:verstappen)
    @norris = drivers(:norris)
  end

  def jolpica_payload(results)
    {
      "MRData" => {
        "RaceTable" => {
          "Races" => [
            {
              "season" => @race.year.to_s,
              "round"  => @race.round.to_s,
              "Results" => results
            }
          ]
        }
      }
    }.to_json
  end

  def result_entry(driver:, constructor_ref:, position:, points:, status: "Finished", grid: nil)
    {
      "Driver" => {
        "driverId" => driver.driver_ref,
        "familyName" => driver.surname,
        "givenName" => driver.forename,
        "dateOfBirth" => "1990-01-01",
        "nationality" => driver.nationality,
        "code" => driver.code,
        "url" => "http://example.com/#{driver.driver_ref}"
      },
      "Constructor" => {
        "constructorId" => constructor_ref,
        "name" => constructor_ref.titleize,
        "url" => "http://example.com/#{constructor_ref}"
      },
      "status" => status,
      "position" => position.to_s,
      "positionOrder" => position,
      "points" => points.to_s,
      "laps" => "57",
      "grid" => (grid || position).to_s,
      "number" => "1"
    }
  end

  def with_jolpica(json)
    URI.stub(:open, ->(*_args, **_kwargs) { StringIO.new(json) }) { yield }
  end

  test "writes race_results from Jolpica payload on a fresh race" do
    payload = jolpica_payload([
      result_entry(driver: @verstappen, constructor_ref: "red_bull", position: 1, points: 25),
      result_entry(driver: @norris,     constructor_ref: "mclaren",  position: 2, points: 18)
    ])

    with_jolpica(payload) do
      assert_difference -> { RaceResult.where(race: @race).count }, 2 do
        UpdateRaceResult.new(race: @race).update_all
      end
    end

    ver = RaceResult.find_by!(race: @race, driver: @verstappen)
    assert_equal 1, ver.position_order
    assert_equal 25.0, ver.points.to_f
  end

  test "network error leaves race results untouched" do
    URI.stub(:open, ->(*_args, **_kwargs) { raise OpenURI::HTTPError.new("503 Service Unavailable", StringIO.new) }) do
      assert_no_difference -> { RaceResult.where(race: @race).count } do
        # Stub the Wikipedia fallback so the network-error path doesn't accidentally
        # exercise the Wikipedia branch; we want to assert pure no-op on fetch fail.
        WikipediaRaceResultFetcher.stub_any_instance(:call, nil) { UpdateRaceResult.new(race: @race).update_all }
      end
    end
  end

  test "empty Jolpica Results triggers Wikipedia fallback when race has a URL" do
    payload = { "MRData" => { "RaceTable" => { "Races" => [{ "Results" => [] }] } } }.to_json
    @race.update!(url: "https://en.wikipedia.org/wiki/2026_Australian_Grand_Prix")

    wiki_calls = 0
    fake_results = [
      { driver: @verstappen, constructor: constructors(:red_bull), status: statuses(:finished),
        position: "1", position_order: 1, points: "25", time: nil, laps: "57", milliseconds: nil,
        fastest_lap_time: nil, fastest_lap_speed: nil, fastest_lap: nil, grid: "1", number: "1" }
    ]

    WikipediaRaceResultFetcher.stub_any_instance(:call, -> { wiki_calls += 1; fake_results }) do
      with_jolpica(payload) do
        UpdateRaceResult.new(race: @race).update_all
      end
    end

    assert_equal 1, wiki_calls, "Wikipedia fetcher should run when Jolpica returns no Results"
    assert RaceResult.where(race: @race, driver: @verstappen).exists?
  end

  test "re-sync with a different result count resets derived state via ResetRaceState" do
    bahrain = races(:bahrain_2026) # already has 4 race_results in fixtures
    # Payload has only 3 results — fewer than the 4 stored, so resync should trigger
    payload = jolpica_payload([
      result_entry(driver: @verstappen, constructor_ref: "red_bull", position: 1, points: 25),
      result_entry(driver: @norris,     constructor_ref: "mclaren",  position: 2, points: 18),
      result_entry(driver: drivers(:leclerc), constructor_ref: "ferrari", position: 3, points: 15)
    ])
    # Swap race so the payload matches bahrain
    payload = payload.sub(@race.year.to_s, bahrain.year.to_s).sub(/"round"\s*=>\s*"#{@race.round}"/, %("round" => "#{bahrain.round}"))

    reset_calls = 0
    ResetRaceState.stub_any_instance(:call, -> { reset_calls += 1 }) do
      with_jolpica(payload) do
        UpdateRaceResult.new(race: bahrain).update_all
      end
    end

    assert_equal 1, reset_calls, "ResetRaceState should run when stored count != incoming"
  end

  test "re-sync with matching result count does NOT call ResetRaceState" do
    bahrain = races(:bahrain_2026) # 4 stored
    payload = jolpica_payload([
      result_entry(driver: @verstappen, constructor_ref: "red_bull", position: 1, points: 25),
      result_entry(driver: @norris,     constructor_ref: "mclaren",  position: 2, points: 18),
      result_entry(driver: drivers(:leclerc), constructor_ref: "ferrari", position: 3, points: 15),
      result_entry(driver: drivers(:piastri), constructor_ref: "mclaren", position: 4, points: 12)
    ])

    reset_calls = 0
    ResetRaceState.stub_any_instance(:call, -> { reset_calls += 1 }) do
      with_jolpica(payload) do
        UpdateRaceResult.new(race: bahrain).update_all
      end
    end

    assert_equal 0, reset_calls
  end
end

# Minitest doesn't ship stub_any_instance; provide a tiny shim that targets
# the next instance to be created. Sufficient for these single-call sites.
class Class
  def stub_any_instance(method, value_or_block)
    original = instance_method(method)
    define_method(method) { |*a, **k, &b| value_or_block.respond_to?(:call) ? value_or_block.call(*a, **k, &b) : value_or_block }
    yield
  ensure
    define_method(method, original) if original
  end
end
