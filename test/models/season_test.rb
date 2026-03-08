require "test_helper"

class SeasonTest < ActiveSupport::TestCase
  # ── Validations ──

  test "requires unique year" do
    dupe = Season.new(year: seasons(:season_2026).year)
    assert_not dupe.valid?
    assert_includes dupe.errors[:year], "has already been taken"
  end

  # ── Scopes ──

  test "sorted_by_year orders descending" do
    sorted = Season.sorted_by_year.to_a
    assert sorted.each_cons(2).all? { |a, b| a.year >= b.year }
  end

  # ── Custom methods ──

  test "to_param returns year string" do
    assert_equal "2026", seasons(:season_2026).to_param
  end

  test "has races" do
    assert_equal 2, seasons(:season_2026).races.count
  end

  test "has season_drivers" do
    assert_equal 4, seasons(:season_2026).season_drivers.count
  end

  test "has drivers through season_drivers" do
    assert_includes seasons(:season_2026).drivers, drivers(:verstappen)
  end

  test "next_season and previous_season" do
    assert_equal seasons(:season_2026), seasons(:season_2025).next_season
    assert_equal seasons(:season_2025), seasons(:season_2026).previous_season
  end

  test "first_race returns earliest race" do
    assert_equal races(:bahrain_2026), seasons(:season_2026).first_race
  end

  test "last_race returns season_end race" do
    assert_equal races(:melbourne_2025), seasons(:season_2025).last_race
  end

  test "latest_driver_standings returns standings from latest race" do
    standings = seasons(:season_2026).latest_driver_standings
    assert standings.any?
    assert standings.all? { |ds| ds.race == races(:bahrain_2026) }
  end
end
