require "test_helper"

class ResetRaceStateTest < ActiveSupport::TestCase
  setup do
    @race = races(:bahrain_2026)
    @verstappen = drivers(:verstappen)
    @red_bull = constructors(:red_bull)

    # bahrain_2026 fixture has old_elo_v2=2380, new_elo_v2=2400 for verstappen.
    # Simulate current live state being post-race.
    @verstappen.update!(elo_v2: 2400.0, peak_elo_v2: 2400.0)
    @red_bull.update!(elo_v2: 2400.0, peak_elo_v2: 2400.0) if @red_bull.respond_to?(:elo_v2)
  end

  test "rolls back driver elo_v2 to derived pre-race state" do
    # No race history before bahrain_2026 -> derived pre-race elo == STARTING_ELO
    ResetRaceState.new(race: @race).call

    @verstappen.reload
    assert_equal EloRatingV2::STARTING_ELO, @verstappen.elo_v2
    assert_equal EloRatingV2::STARTING_ELO, @verstappen.peak_elo_v2
  end

  test "uses most recent prior race's new_elo_v2 when prior history exists" do
    # bahrain_2026 is round 1 — give it a synthetic prior race in a much older season.
    older_race = races(:bahrain_2025)
    RaceResult.create!(
      race: older_race, driver: @verstappen, constructor: @red_bull,
      status: statuses(:finished), position: 1, position_order: 1, points: 25,
      new_elo_v2: 2380.0
    )

    ResetRaceState.new(race: @race).call

    @verstappen.reload
    assert_equal 2380.0, @verstappen.elo_v2
    assert_equal 2380.0, @verstappen.peak_elo_v2
  end

  test "wipes race_results, driver_standings, and resets RacePick.score" do
    DriverStanding.where(race: @race, driver: @verstappen).first_or_create!(position: 1, points: 25.0, wins: 1)
    pick = RacePick.create!(user: users(:codex), race: @race,
                            picks: [{ "driver_id" => @verstappen.id, "position" => 1 }],
                            score: 123)

    ResetRaceState.new(race: @race).call

    assert_equal 0, RaceResult.unscoped.where(race: @race).count
    assert_equal 0, DriverStanding.where(race: @race).count
    assert_nil pick.reload.score
  end

  test "prunes orphan SeasonDriver rows minted by a bad sync but keeps backed ones" do
    # Simulate the R6 Monaco bug: a partial Jolpica response stamped a wrong
    # (driver, constructor) tuple on bahrain_2026, creating a stray SeasonDriver
    # row that has no race_result backing it. Add a second race in the same
    # season (melbourne_2026) where Verstappen still races for Red Bull, so the
    # legit Red Bull SeasonDriver row stays backed after bahrain is wiped.
    melbourne = races(:melbourne_2026)
    RaceResult.create!(race: melbourne, driver: @verstappen, constructor: @red_bull,
                       status: statuses(:finished), position: 1, position_order: 1,
                       points: 25, laps: 58)

    ferrari = constructors(:ferrari)
    orphan = SeasonDriver.create!(season: @race.season, driver: @verstappen,
                                  constructor: ferrari, active: true)
    legit = season_drivers(:verstappen_2026)  # driver: verstappen, constructor: red_bull

    ResetRaceState.new(race: @race).call

    assert_nil SeasonDriver.find_by(id: orphan.id), "orphan (verstappen/Ferrari) is removed"
    assert SeasonDriver.find_by(id: legit.id), "legit (verstappen/Red Bull) survives — still backed by Melbourne"
  end

  test "removes all SeasonDriver rows for an affected driver when nothing remains backed" do
    # Verstappen's only 2026 race is bahrain. After wiping bahrain, no
    # constructor pairing is backed for him this season — prune everything.
    # Re-sync would recreate the legit row from the next Jolpica fetch.
    legit_id = season_drivers(:verstappen_2026).id

    ResetRaceState.new(race: @race).call

    assert_nil SeasonDriver.find_by(id: legit_id)
    assert_equal 0, SeasonDriver.where(season: @race.season, driver: @verstappen).count
  end
end
