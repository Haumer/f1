require "test_helper"

class Fantasy::Stock::SettleRaceTest < ActiveSupport::TestCase
  setup do
    @race = races(:bahrain_2026)
    @portfolio = fantasy_stock_portfolios(:codex_stock_2026)
    # Clear existing stock snapshots so settlement can run
    FantasyStockSnapshot.where(fantasy_stock_portfolio: @portfolio, race: @race).destroy_all
  end

  test "creates snapshot for each portfolio" do
    Fantasy::Stock::SettleRace.new(race: @race).call

    snap = FantasyStockSnapshot.find_by(fantasy_stock_portfolio: @portfolio, race: @race)
    assert snap
    assert snap.value.present?
    assert snap.cash.present?
  end

  test "pays dividends to long holders based on race result position" do
    cash_before = @portfolio.cash
    Fantasy::Stock::SettleRace.new(race: @race).call

    # verstappen won (P1) -> 0.5% dividend
    @portfolio.reload
    holding = fantasy_stock_holdings(:codex_ver_long)
    share_price = @portfolio.share_price(holding.driver)
    dividend_per = (share_price * 0.005).round(2)
    expected_dividend = dividend_per * holding.quantity

    tx = @portfolio.transactions.find_by(kind: "dividend", driver: drivers(:verstappen))
    assert tx, "Expected dividend transaction for verstappen"
    assert_in_delta expected_dividend, tx.amount, 0.1
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

  test "dividend rate for P1 is 0.5%" do
    assert_equal 0.005, Fantasy::Stock::SettleRace::DIVIDEND_RATES[1]
  end

  test "dividend rate for P2 is 0.3%" do
    assert_equal 0.003, Fantasy::Stock::SettleRace::DIVIDEND_RATES[2]
  end

  test "dividend rate for P3 is 0.2%" do
    assert_equal 0.002, Fantasy::Stock::SettleRace::DIVIDEND_RATES[3]
  end

  test "dividend rate for P4-P10 is 0.1%" do
    assert_equal 0.001, Fantasy::Stock::SettleRace::POINTS_DIVIDEND_RATE
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
