require "test_helper"
require "minitest/mock"

class UpdateQualifyingResultTest < ActiveSupport::TestCase
  setup do
    @race = races(:melbourne_2026)
    @race.update!(url: "https://en.wikipedia.org/wiki/2026_Australian_Grand_Prix")
  end

  def jolpica(results)
    {
      "MRData" => { "RaceTable" => { "Races" => results.nil? ? [] : [{ "QualifyingResults" => results }] } }
    }.to_json
  end

  def jolpica_row(driver, constructor, position, q1:, q2: nil, q3: nil)
    { "position" => position.to_s, "Q1" => q1, "Q2" => q2, "Q3" => q3,
      "Driver" => { "driverId" => driver.driver_ref },
      "Constructor" => { "constructorId" => constructor.constructor_ref } }
  end

  def with_jolpica(json)
    URI.stub(:open, ->(*_args, **_kwargs) { StringIO.new(json) }) { yield }
  end

  def wiki_rows
    [
      { driver: drivers(:norris), constructor: constructors(:mclaren), position: 1, q1: "1:20.1", q2: "1:19.9", q3: "1:19.5" },
      { driver: drivers(:leclerc), constructor: constructors(:ferrari), position: 2, q1: "1:20.2", q2: "1:20.0", q3: nil },
    ]
  end

  test "uses Jolpica when it has the classification and does not touch Wikipedia" do
    rows = [jolpica_row(drivers(:verstappen), constructors(:red_bull), 1, q1: "1:20.0", q3: "1:19.0")]
    fetcher = Minitest::Mock.new # no `call` expectation: any call fails the test

    count = WikipediaQualifyingResultFetcher.stub(:new, ->(*) { fetcher }) do
      with_jolpica(jolpica(rows)) { UpdateQualifyingResult.new(race: @race).call }
    end

    assert_equal 1, count
    stored = @race.qualifying_results.find_by(driver: drivers(:verstappen))
    assert_equal [1, "1:20.0", nil, "1:19.0"], [stored.position, stored.q1, stored.q2, stored.q3]
    assert_equal constructors(:red_bull), stored.constructor
  end

  test "falls back to Wikipedia when Jolpica has no rows yet" do
    fetcher = Minitest::Mock.new
    fetcher.expect(:call, wiki_rows)

    updater = UpdateQualifyingResult.new(race: @race)
    count = WikipediaQualifyingResultFetcher.stub(:new, ->(*) { fetcher }) do
      with_jolpica(jolpica([])) { updater.call }
    end

    fetcher.verify
    assert_equal 2, count
    assert_equal "wikipedia", updater.source
    assert_equal [1, 2], @race.qualifying_results.sorted.map(&:position)
    assert_nil @race.qualifying_results.find_by(driver: drivers(:leclerc)).q3
  end

  test "treats a Jolpica network error as 'nothing published yet' and still tries Wikipedia" do
    fetcher = Minitest::Mock.new
    fetcher.expect(:call, wiki_rows)

    count = WikipediaQualifyingResultFetcher.stub(:new, ->(*) { fetcher }) do
      URI.stub(:open, ->(*_args, **_kwargs) { raise Net::ReadTimeout }) do
        UpdateQualifyingResult.new(race: @race).call
      end
    end

    assert_equal 2, count
  end

  test "returns 0 and writes nothing when no source has published" do
    fetcher = Minitest::Mock.new
    fetcher.expect(:call, nil)

    count = WikipediaQualifyingResultFetcher.stub(:new, ->(*) { fetcher }) do
      with_jolpica(jolpica(nil)) { UpdateQualifyingResult.new(race: @race).call }
    end

    assert_equal 0, count
    assert_empty @race.qualifying_results
  end

  test "skips Wikipedia when the race has no article URL" do
    @race.update!(url: nil)
    fetcher = Minitest::Mock.new

    count = WikipediaQualifyingResultFetcher.stub(:new, ->(*) { fetcher }) do
      with_jolpica(jolpica([])) { UpdateQualifyingResult.new(race: @race).call }
    end

    assert_equal 0, count
  end

  test "a later, fuller source overwrites earlier rows instead of duplicating them" do
    QualifyingResult.create!(race: @race, driver: drivers(:norris), position: 5, q1: "9:99.9")
    fetcher = Minitest::Mock.new
    fetcher.expect(:call, wiki_rows)

    WikipediaQualifyingResultFetcher.stub(:new, ->(*) { fetcher }) do
      with_jolpica(jolpica([])) { UpdateQualifyingResult.new(race: @race).call }
    end

    assert_equal 1, @race.qualifying_results.where(driver: drivers(:norris)).count
    assert_equal 1, @race.qualifying_results.find_by(driver: drivers(:norris)).position
  end
end
