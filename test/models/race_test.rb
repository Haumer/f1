require "test_helper"

class RaceTest < ActiveSupport::TestCase
  # ── Validations ──

  test "requires date" do
    race = Race.new(round: 1, circuit: circuits(:bahrain), season: seasons(:season_2026))
    assert_not race.valid?
    assert_includes race.errors[:date], "can't be blank"
  end

  test "requires round" do
    race = Race.new(date: Date.new(2026, 4, 1), circuit: circuits(:bahrain), season: seasons(:season_2026))
    assert_not race.valid?
    assert_includes race.errors[:round], "can't be blank"
  end

  test "round must be unique within season" do
    existing = races(:bahrain_2026)
    dupe = Race.new(
      round: existing.round,
      date: Date.new(2026, 5, 1),
      circuit: circuits(:melbourne),
      season: existing.season
    )
    assert_not dupe.valid?
    assert_includes dupe.errors[:round], "has already been taken"
  end

  test "same round in different seasons is allowed" do
    assert_equal races(:bahrain_2025).round, races(:bahrain_2026).round
    assert races(:bahrain_2025).valid?
    assert races(:bahrain_2026).valid?
  end

  # ── Associations ──

  test "has race results" do
    assert_equal 4, races(:bahrain_2026).race_results.count
  end

  test "has drivers through race results" do
    assert_includes races(:bahrain_2026).drivers, drivers(:verstappen)
  end

  test "belongs to circuit and season" do
    race = races(:bahrain_2026)
    assert_equal circuits(:bahrain), race.circuit
    assert_equal seasons(:season_2026), race.season
  end

  # ── Scopes ──

  test "sorted orders by date ascending" do
    sorted = Race.sorted.to_a
    assert sorted.each_cons(2).all? { |a, b| a.date <= b.date }
  end

  test "sorted_by_most_recent orders by date descending" do
    sorted = Race.sorted_by_most_recent.to_a
    assert sorted.each_cons(2).all? { |a, b| a.date >= b.date }
  end

  # ── Custom methods ──

  test "highest_elo_race_result returns result with max new_elo_v2" do
    best = races(:bahrain_2026).highest_elo_race_result
    assert_equal drivers(:verstappen), best.driver
  end

  test "average_elos computes mean of new_elo_v2" do
    expected = [2400.0, 2200.0, 2150.0, 2050.0].sum / 4.0
    assert_in_delta expected, races(:bahrain_2026).average_elos, 0.1
  end

  test "has_results? is true when results exist" do
    assert races(:bahrain_2026).has_results?
  end

  test "has_results? is false when no results" do
    assert_not races(:melbourne_2026).has_results?
  end

  test "previous_race returns prior race in season" do
    assert_equal races(:bahrain_2026), races(:melbourne_2026).previous_race
  end

  test "next_race returns following race in season" do
    assert_equal races(:melbourne_2026), races(:bahrain_2026).next_race
  end

  test "driver_standing_for returns standing for driver" do
    standing = races(:bahrain_2026).driver_standing_for(drivers(:verstappen))
    assert_equal 1, standing.position
    assert_equal 25.0, standing.points
  end

  test "session_schedule returns array with Race session" do
    schedule = races(:bahrain_2026).session_schedule
    assert_kind_of Array, schedule
    assert schedule.any? { |s| s[:name] == "Race" }
  end
end
