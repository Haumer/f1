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

  test "two snapshots returns simple diff regardless of starting_values" do
    ids = [@codex_portfolio.id]
    deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, ids,
      starting_values: { @codex_portfolio.id => 999_999 })

    # 8800 - 8500 = 300 (starting_values ignored when 2+ snapshots exist)
    assert_equal 300.0, deltas[@codex_portfolio.id]
  end

  # ── Single-snapshot: stock portfolio predates snapshot → use total_starting_capital ──

  test "single snapshot uses total_starting_capital when stock portfolio predates snapshot" do
    # Delete codex melbourne snapshot → only bahrain remains
    fantasy_snapshots(:codex_melbourne).destroy!

    # Make stock portfolio predate the bahrain snapshot
    bahrain_snap = fantasy_snapshots(:codex_bahrain)
    @codex_stock.update_columns(created_at: bahrain_snap.created_at - 1.day)

    # Build starting_values the same way compute_combined_deltas does
    sp = @codex_portfolio.stock_portfolio
    earliest_snap = @codex_portfolio.snapshots.order(:created_at).first
    stock_existed = sp && earliest_snap && sp.created_at <= earliest_snap.created_at
    starting_value = stock_existed ? @codex_portfolio.total_starting_capital : @codex_portfolio.starting_capital

    assert stock_existed, "Stock portfolio should predate the snapshot"
    assert_equal 6000.0, starting_value, "Should use total_starting_capital (4000 + 2000)"

    deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, [@codex_portfolio.id],
      starting_values: { @codex_portfolio.id => starting_value })

    # 8500 - 6000 = 2500
    assert_equal 2500.0, deltas[@codex_portfolio.id]
  end

  # ── Single-snapshot: stock portfolio created AFTER snapshot → use starting_capital only ──

  test "single snapshot uses starting_capital when stock portfolio created after snapshot" do
    # Delete latejoin melbourne snapshot → only bahrain remains
    fantasy_snapshots(:latejoin_melbourne).destroy!

    # latejoin_stock_2026 has created_at: 2026-03-12 (after bahrain snap at 2026-03-09)
    sp = @latejoin_portfolio.stock_portfolio
    earliest_snap = @latejoin_portfolio.snapshots.order(:created_at).first
    stock_existed = sp && earliest_snap && sp.created_at <= earliest_snap.created_at

    refute stock_existed, "Stock portfolio should NOT predate the snapshot"
    starting_value = stock_existed ? @latejoin_portfolio.total_starting_capital : @latejoin_portfolio.starting_capital
    assert_equal 4000.0, starting_value, "Should use starting_capital (4000), not total (6000)"

    deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, [@latejoin_portfolio.id],
      starting_values: { @latejoin_portfolio.id => starting_value })

    # 4200 - 4000 = 200
    assert_equal 200.0, deltas[@latejoin_portfolio.id]
  end

  # ── Verify the BUG scenario: using total_starting_capital incorrectly shows false loss ──

  test "using total_starting_capital incorrectly for late stock user shows false loss" do
    # This test documents the bug that was fixed
    fantasy_snapshots(:latejoin_melbourne).destroy!

    # If we incorrectly use total_starting_capital for a user whose stock
    # portfolio was created after the snapshot...
    wrong_starting_value = @latejoin_portfolio.total_starting_capital
    assert_equal 6000.0, wrong_starting_value

    deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, [@latejoin_portfolio.id],
      starting_values: { @latejoin_portfolio.id => wrong_starting_value })

    # 4200 - 6000 = -1800 ← FALSE LOSS (the bug)
    assert_equal(-1800.0, deltas[@latejoin_portfolio.id],
      "Using total_starting_capital incorrectly produces a false loss")
  end

  # ── No snapshots ──

  test "no snapshots returns zero delta" do
    FantasySnapshot.where(fantasy_portfolio_id: @latejoin_portfolio.id).destroy_all
    deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, [@latejoin_portfolio.id],
      starting_values: { @latejoin_portfolio.id => 4000 })

    assert_nil deltas[@latejoin_portfolio.id], "No snapshots should produce no entry in deltas hash"
  end

  # ── Stock snapshots ──

  test "stock snapshot delta uses simple diff with two snapshots" do
    ids = [@codex_stock.id]
    deltas = last_race_deltas(FantasyStockSnapshot, :fantasy_stock_portfolio_id, ids)

    # 4500 - 4200 = 300
    assert_equal 300.0, deltas[@codex_stock.id]
  end

  test "stock snapshot single entry uses starting_values" do
    # latejoin only has one stock snapshot (melbourne)
    ids = [@latejoin_stock.id]
    deltas = last_race_deltas(FantasyStockSnapshot, :fantasy_stock_portfolio_id, ids,
      starting_values: { @latejoin_stock.id => @latejoin_stock.total_invested })

    # 2300 - total_invested
    expected = 2300.0 - @latejoin_stock.total_invested
    assert_equal expected, deltas[@latejoin_stock.id]
  end
end
