require "test_helper"

class DriverStandingTest < ActiveSupport::TestCase
  test "belongs to race and driver" do
    ds = driver_standings(:bahrain_2026_verstappen)
    assert_equal races(:bahrain_2026), ds.race
    assert_equal drivers(:verstappen), ds.driver
  end

  test "standings reflect correct points and position" do
    ds = driver_standings(:bahrain_2026_verstappen)
    assert_equal 25.0, ds.points
    assert_equal 1, ds.position
    assert_equal 1, ds.wins
  end

  test "season_end flag marks final standings" do
    ds = driver_standings(:melbourne_2025_verstappen)
    assert ds.season_end?
    assert_equal 400.0, ds.points
  end

  test "champion standings query finds title winners" do
    champions = DriverStanding.where(position: 1, season_end: true)
    assert_includes champions.map(&:driver), drivers(:verstappen)
  end
end
