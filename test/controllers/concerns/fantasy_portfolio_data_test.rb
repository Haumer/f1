require "test_helper"

class FantasyPortfolioDataTest < ActiveSupport::TestCase
  # Include the concern so we can test last_race_deltas directly
  include FantasyPortfolioData

  setup do
    @codex_portfolio = fantasy_portfolios(:codex_2026)
    @codex_stock = fantasy_stock_portfolios(:codex_stock_2026)
    @latejoin_portfolio = fantasy_portfolios(:latejoin_2026)
    @latejoin_stock = fantasy_stock_portfolios(:latejoin_stock_2026)
  end

  # ── last_race_deltas with two snapshots ──

  test "two snapshots returns simple diff" do
    ids = [@codex_portfolio.id]
    deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, ids)

    # 8800 - 8500 = 300
    assert_equal 300.0, deltas[@codex_portfolio.id]
  end

  test "two snapshots ignores starting_values" do
    ids = [@codex_portfolio.id]
    deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, ids,
      starting_values: { @codex_portfolio.id => 999_999 })

    # Still 8800 - 8500 = 300
    assert_equal 300.0, deltas[@codex_portfolio.id]
  end

  # ── Single-snapshot uses starting_values as baseline ──

  test "single snapshot compares against starting capital" do
    fantasy_snapshots(:codex_melbourne).destroy!

    deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, [@codex_portfolio.id],
      starting_values: { @codex_portfolio.id => 6000 })

    # 8500 (bahrain snapshot) - 6000 (starting capital) = 2500
    assert_equal 2500.0, deltas[@codex_portfolio.id]
  end

  test "single snapshot for late-stock user compares against starting capital" do
    fantasy_snapshots(:latejoin_melbourne).destroy!

    deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, [@latejoin_portfolio.id],
      starting_values: { @latejoin_portfolio.id => 4000 })

    # snapshot value - 4000 = gain from first race
    snap = fantasy_snapshots(:latejoin_bahrain)
    assert_equal snap.value - 4000, deltas[@latejoin_portfolio.id]
  end

  # ── No snapshots ──

  test "no snapshots returns no entry in deltas hash" do
    FantasySnapshot.where(fantasy_portfolio_id: @latejoin_portfolio.id).destroy_all
    deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, [@latejoin_portfolio.id])

    assert_nil deltas[@latejoin_portfolio.id]
  end

  # ── Stock snapshots ──

  test "stock snapshot delta uses simple diff with two snapshots" do
    ids = [@codex_stock.id]
    deltas = last_race_deltas(FantasyStockSnapshot, :fantasy_stock_portfolio_id, ids)

    # 4500 - 4200 = 300
    assert_equal 300.0, deltas[@codex_stock.id]
  end

  test "stock snapshot single entry compares against starting capital" do
    # latejoin only has one stock snapshot (melbourne)
    ids = [@latejoin_stock.id]
    starting = @latejoin_stock.starting_capital
    deltas = last_race_deltas(FantasyStockSnapshot, :fantasy_stock_portfolio_id, ids,
      starting_values: { @latejoin_stock.id => starting })

    snap = @latejoin_stock.snapshots.first
    assert_equal snap.value - starting, deltas[@latejoin_stock.id]
  end

  # ── compute_combined_deltas starting_value logic ──
  # These tests verify the starting_value selection logic used in the controller,
  # even though single-snapshot deltas now return 0. The logic matters once users
  # have 2+ snapshots.

  test "starting_value uses total_starting_capital when stock portfolio predates snapshot" do
    bahrain_snap = fantasy_snapshots(:codex_bahrain)
    @codex_stock.update_columns(created_at: bahrain_snap.created_at - 1.day)

    sp = @codex_portfolio.stock_portfolio
    earliest_snap = @codex_portfolio.snapshots.order(:created_at).first
    stock_existed = sp && earliest_snap && sp.created_at <= earliest_snap.created_at

    assert stock_existed
    starting_value = stock_existed ? @codex_portfolio.total_starting_capital : @codex_portfolio.starting_capital
    assert_equal 6000.0, starting_value, "Should use total_starting_capital (4000 + 2000)"
  end

  test "starting_value uses starting_capital when stock portfolio created after snapshot" do
    sp = @latejoin_portfolio.stock_portfolio
    earliest_snap = @latejoin_portfolio.snapshots.order(:created_at).first
    stock_existed = sp && earliest_snap && sp.created_at <= earliest_snap.created_at

    refute stock_existed
    starting_value = stock_existed ? @latejoin_portfolio.total_starting_capital : @latejoin_portfolio.starting_capital
    assert_equal 4000.0, starting_value, "Should use starting_capital (4000), not total (6000)"
  end
end
