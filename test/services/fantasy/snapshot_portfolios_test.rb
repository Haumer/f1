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

  test "creates snapshots for all portfolios in the race season" do
    count = Fantasy::SnapshotPortfolios.new(race: @race).call
    assert_equal 1, count

    snap = FantasySnapshot.find_by(fantasy_portfolio: @portfolio, race: @race)
    assert snap
    assert snap.value.present?
    assert snap.cash.present?
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
