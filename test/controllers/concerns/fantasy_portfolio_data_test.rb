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

  # ── Starting capital ──

  test "starting_capital is present on portfolio" do
    assert @codex_portfolio.starting_capital.present?
  end
end
