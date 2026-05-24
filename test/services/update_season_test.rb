require "test_helper"
require "minitest/mock"

class UpdateSeasonTest < ActiveSupport::TestCase
  # Build a Jolpica-shaped season payload for the given round numbers.
  def feed_json(rounds)
    races = rounds.map do |rd|
      {
        "season" => "2099",
        "round"  => rd.to_s,
        "date"   => format("2099-03-%02d", rd),
        "url"    => "http://example.com/r#{rd}",
        "Circuit" => {
          "circuitId"   => "albert_park",
          "circuitName" => "Albert Park",
          "Location"    => { "locality" => "Melbourne", "country" => "Australia", "lat" => "-37.8", "long" => "144.9" },
          "url"         => "http://example.com/circuit",
        },
      }
    end
    { "MRData" => { "RaceTable" => { "Races" => races } } }.to_json
  end

  def run_update(rounds)
    URI.stub(:open, ->(*_args, **_kwargs) { StringIO.new(feed_json(rounds)) }) do
      UpdateSeason.new(year: "2099").create_season
    end
  end

  test "reconciles the calendar: cancels dropped rounds, protects results, revives returning rounds, fixes season_end" do
    season  = Season.create!(year: "2099")
    circuit = circuits(:melbourne)

    in_feed       = Race.create!(season: season, round: 1, date: "2099-03-01", circuit: circuit)
    returning     = Race.create!(season: season, round: 2, date: "2099-03-02", circuit: circuit, cancelled: true)
    dropped_empty = Race.create!(season: season, round: 5, date: "2099-04-01", circuit: circuit, season_end: true)
    dropped_with_results = Race.create!(season: season, round: 0, date: "2099-02-01", circuit: circuit)
    RaceResult.create!(race: dropped_with_results, driver: drivers(:verstappen),
                       constructor: constructors(:red_bull), status: statuses(:finished),
                       position: 1, position_order: 1)

    run_update([1, 2, 3])

    assert_not Race.with_cancelled.find(in_feed.id).cancelled?, "round in feed stays active"
    assert_not Race.with_cancelled.find(returning.id).cancelled?, "round that returned to the feed is revived"

    created = Race.with_cancelled.find_by(season: season, round: 3)
    assert created, "round newly present in the feed is created"
    assert_not created.cancelled?

    dropped_empty.reload
    assert dropped_empty.cancelled?, "round dropped from the feed with no results is cancelled"
    assert_not dropped_empty.season_end?, "stale season_end flag is cleared when cancelling"

    assert_not Race.with_cancelled.find(dropped_with_results.id).cancelled?,
               "a race that already has results is never auto-cancelled"

    # season_end lands on the highest active round (3), not a cancelled/stale one.
    assert created.reload.season_end?
    assert_equal 1, season.races.where(season_end: true).count
  end

  test "default scope hides cancelled races but with_cancelled reveals them" do
    season  = Season.create!(year: "2099")
    circuit = circuits(:melbourne)
    active    = Race.create!(season: season, round: 1, date: "2099-03-01", circuit: circuit)
    cancelled = Race.create!(season: season, round: 2, date: "2099-03-02", circuit: circuit, cancelled: true)

    assert_includes season.races.to_a, active
    assert_not_includes season.races.to_a, cancelled
    assert_includes season.races.with_cancelled.to_a, cancelled
    assert_raises(ActiveRecord::RecordNotFound) { Race.find(cancelled.id) }
    assert_equal cancelled, Race.with_cancelled.find(cancelled.id)
  end
end
