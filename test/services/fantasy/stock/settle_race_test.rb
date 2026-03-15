require "test_helper"

class Fantasy::Stock::SettleRaceTest < ActiveSupport::TestCase
  setup do
    @race = races(:bahrain_2026)
    @portfolio = fantasy_stock_portfolios(:codex_stock_2026)
    # Clear existing stock snapshots so settlement can run
    FantasyStockSnapshot.where(fantasy_stock_portfolio: @portfolio, race: @race).destroy_all
    # Ensure holdings predate the race so they're eligible for settlement
    @portfolio.holdings.update_all(created_at: @race.date - 1.day)
  end

  test "creates snapshot for each portfolio" do
    Fantasy::Stock::SettleRace.new(race: @race).call

    snap = FantasyStockSnapshot.find_by(fantasy_stock_portfolio: @portfolio, race: @race)
    assert snap
    assert snap.value.present?
    assert snap.cash.present?
  end

  test "pays dividends to long holders based on race result position" do
    Fantasy::Stock::SettleRace.new(race: @race).call

    @portfolio.reload

    tx = @portfolio.transactions.find_by(kind: "dividend", driver: drivers(:verstappen))
    assert tx, "Expected dividend transaction for verstappen"
    assert tx.amount > 0, "Dividend should be positive"
  end

  test "charges borrow fees for short holders" do
    Fantasy::Stock::SettleRace.new(race: @race).call

    tx = @portfolio.transactions.find_by(kind: "borrow_fee", driver: drivers(:norris))
    assert tx, "Expected borrow fee transaction for norris short"
    assert tx.amount.negative?
  end

  test "is idempotent - skips already-settled portfolios" do
    Fantasy::Stock::SettleRace.new(race: @race).call
    tx_count = @portfolio.transactions.count
    Fantasy::Stock::SettleRace.new(race: @race).call
    assert_equal tx_count, @portfolio.transactions.count
  end

  test "dividend base is 0.10" do
    assert_equal 0.10, Fantasy::Stock::SettleRace::DIVIDEND_BASE
  end

  test "dividend surprise bonus is 0.02" do
    assert_equal 0.02, Fantasy::Stock::SettleRace::DIVIDEND_SURPRISE_BONUS
  end

  test "constructor multiplier range is 0.5 to 5.0" do
    assert_equal 0.5, Fantasy::Stock::SettleRace::CONSTRUCTOR_MULT_MIN
    assert_equal 5.0, Fantasy::Stock::SettleRace::CONSTRUCTOR_MULT_MAX
  end

  test "borrow fee rate is 0.25%" do
    assert_equal 0.0025, Fantasy::Stock::SettleRace::BORROW_FEE_RATE
  end

  test "auto-liquidates short when price exceeds 2x max loss" do
    holding = fantasy_stock_holdings(:codex_nor_short)
    # Set entry_price very low so current price exceeds 3x entry (1 + MAX_LOSS_MULTIPLIER)
    holding.update_columns(entry_price: 1.0)

    Fantasy::Stock::SettleRace.new(race: @race).call

    holding.reload
    refute holding.active, "Short should be auto-liquidated"

    tx = @portfolio.transactions.find_by(kind: "liquidation", driver: drivers(:norris))
    assert tx, "Expected liquidation transaction"
  end
end
