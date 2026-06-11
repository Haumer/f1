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

  # adjust_demand! is called inside trade services that themselves run inside
  # buy_batch's outer ActiveRecord transaction. Verifies the savepoint nests
  # correctly — an outer Rollback must revert demand or buy_batch leaks state
  # on partial failure.
  test "adjust_demand! rolls back with outer transaction" do
    sd = season_drivers(:verstappen_2026)
    start = sd.net_demand
    ActiveRecord::Base.transaction do
      SeasonDriver.adjust_demand!(sd.driver_id, sd.season_id, 5)
      assert_equal start + 5, sd.reload.net_demand, "should see uncommitted +5 within transaction"
      raise ActiveRecord::Rollback
    end
    assert_equal start, sd.reload.net_demand, "outer rollback must revert adjust_demand"
  end
end
