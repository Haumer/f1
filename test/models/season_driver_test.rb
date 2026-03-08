require "test_helper"

class SeasonDriverTest < ActiveSupport::TestCase
  test "belongs to driver, season, and constructor" do
    sd = season_drivers(:verstappen_2026)
    assert_equal drivers(:verstappen), sd.driver
    assert_equal seasons(:season_2026), sd.season
    assert_equal constructors(:red_bull), sd.constructor
  end

  test "links driver to correct team for season" do
    assert_equal constructors(:mclaren), season_drivers(:norris_2026).constructor
  end
end
