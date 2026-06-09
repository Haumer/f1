require "test_helper"

class SeasonSyncTest < ActiveSupport::TestCase
  # season_2026 fixture has 4 active SeasonDrivers, so expected_driver_count == 4.
  # bahrain_2026 fixture has 4 race_results (full); melbourne_2026 has 0.

  setup do
    @season = seasons(:season_2026)
    @bahrain = races(:bahrain_2026)     # 4/4 results, 2026-03-08
    @melbourne = races(:melbourne_2026) # 0 results, 2026-03-22
  end

  test "expected_driver_count returns active SeasonDriver count for the season" do
    assert_equal 4, SeasonSync.expected_driver_count(@season)
  end

  test "race with zero results is in races_needing_update" do
    travel_to Time.zone.parse("2026-03-23 18:00") do
      assert_includes SeasonSync.races_needing_update(@season), @melbourne
    end
  end

  test "race with a complete result set is NOT in races_needing_update" do
    travel_to Time.zone.parse("2026-03-09 18:00") do
      refute_includes SeasonSync.races_needing_update(@season), @bahrain
    end
  end

  test "race with partial results within retry window IS in races_needing_update" do
    # Drop one of bahrain's 4 race_results, leaving 3/4 — a partial sync state.
    race_results(:bahrain_2026_piastri).destroy!

    travel_to Time.zone.parse("2026-03-09 18:00") do
      assert_includes SeasonSync.races_needing_update(@season), @bahrain
    end
  end

  test "race with partial results past the retry window is NOT retried" do
    race_results(:bahrain_2026_piastri).destroy!

    # Travel past the 14-day window for bahrain (2026-03-08).
    travel_to Time.zone.parse("2026-04-01 18:00") do
      refute_includes SeasonSync.races_needing_update(@season), @bahrain
    end
  end

  test "stale? returns true when any race needs update" do
    travel_to Time.zone.parse("2026-03-23 18:00") do
      Season.where(year: "2026").update_all(year: Date.current.year.to_s)
      assert_predicate SeasonSync, :stale?
    end
  end
end
