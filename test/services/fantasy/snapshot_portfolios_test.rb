require "test_helper"

class Fantasy::SnapshotPortfoliosTest < ActiveSupport::TestCase
  setup do
    @race = races(:bahrain_2025) # use a race with no existing snapshots for this test
    @portfolio = fantasy_portfolios(:codex_2026)
    # Point portfolio to 2025 season temporarily for this race
    @portfolio.update_columns(season_id: seasons(:season_2025).id)
  end

  teardown do
    @portfolio.update_columns(season_id: seasons(:season_2026).id)
  end

  test "creates snapshots: value == cash + stock_value, cash == portfolio.cash" do
    count = Fantasy::SnapshotPortfolios.new(race: @race).call
    assert_equal 1, count

    snap = FantasySnapshot.find_by(fantasy_portfolio: @portfolio, race: @race)
    assert snap
    @portfolio.reload
    assert_equal @portfolio.cash, snap.cash, "snapshot.cash mirrors live cash at write time"
    assert snap.value >= snap.cash, "value = cash + stock_value, so value >= cash always"
  end

  test "assigns rank based on net P&L" do
    Fantasy::SnapshotPortfolios.new(race: @race).call
    snap = FantasySnapshot.find_by(fantasy_portfolio: @portfolio, race: @race)
    assert_equal 1, snap.rank
  end

  test "upserts existing snapshots idempotently" do
    Fantasy::SnapshotPortfolios.new(race: @race).call
    Fantasy::SnapshotPortfolios.new(race: @race).call # run again

    assert_equal 1, FantasySnapshot.where(fantasy_portfolio: @portfolio, race: @race).count
  end
end
