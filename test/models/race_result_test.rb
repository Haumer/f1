require "test_helper"

class RaceResultTest < ActiveSupport::TestCase
  # ── Validations ──

  test "requires driver_id, race_id, and constructor_id" do
    rr = RaceResult.new
    assert_not rr.valid?
    assert_includes rr.errors[:driver_id], "can't be blank"
    assert_includes rr.errors[:race_id], "can't be blank"
    assert_includes rr.errors[:constructor_id], "can't be blank"
  end

  test "valid race result" do
    assert race_results(:bahrain_2026_verstappen).valid?
  end

  # ── Associations ──

  test "belongs to race, driver, constructor, and status" do
    rr = race_results(:bahrain_2026_verstappen)
    assert_equal races(:bahrain_2026), rr.race
    assert_equal drivers(:verstappen), rr.driver
    assert_equal constructors(:red_bull), rr.constructor
    assert_equal statuses(:finished), rr.status
  end

  test "has season through race" do
    assert_equal seasons(:season_2026), race_results(:bahrain_2026_verstappen).season
  end

  # ── Elo methods ──

  test "elo_diff computes new minus old" do
    rr = race_results(:bahrain_2026_verstappen)
    assert_in_delta 20.0, rr.elo_diff, 0.01
  end

  test "elo_diff returns 0 when elos are nil" do
    assert_equal 0, RaceResult.new.elo_diff
  end

  test "gained_elo? is true for positive diff" do
    assert race_results(:bahrain_2026_verstappen).gained_elo?
  end

  test "gained_elo? is false for negative diff" do
    assert_not race_results(:bahrain_2026_piastri).gained_elo?
  end

  test "display methods delegate correctly" do
    rr = race_results(:bahrain_2026_norris)
    assert_equal rr.old_elo_v2, rr.display_old_elo
    assert_equal rr.new_elo_v2, rr.display_new_elo
    assert_equal rr.elo_diff, rr.display_elo_diff
    assert_equal rr.gained_elo?, rr.display_gained_elo?
  end
end
