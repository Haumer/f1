require "test_helper"

class FantasyStockSnapshotTest < ActiveSupport::TestCase
  test "belongs to fantasy_stock_portfolio" do
    snap = fantasy_stock_snapshots(:codex_stock_bahrain)
    assert_equal fantasy_stock_portfolios(:codex_stock_2026), snap.fantasy_stock_portfolio
  end

  test "belongs to race" do
    snap = fantasy_stock_snapshots(:codex_stock_bahrain)
    assert_equal races(:bahrain_2026), snap.race
  end

  test "stores value and cash" do
    snap = fantasy_stock_snapshots(:codex_stock_bahrain)
    assert_in_delta 4200.0, snap.value, 0.01
    assert_in_delta 3000.0, snap.cash, 0.01
  end
end
