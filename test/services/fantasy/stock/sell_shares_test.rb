require "test_helper"

class Fantasy::Stock::SellSharesTest < ActiveSupport::TestCase
  setup do
    @portfolio = fantasy_stock_portfolios(:codex_stock_2026)
    @driver = drivers(:verstappen) # has an active long holding
    @race = races(:melbourne_2026)
    @race.update_columns(date: 1.week.from_now.to_date, time: "15:00:00")
  end

  test "successfully sells all shares" do
    holding = @portfolio.active_longs.find_by(driver: @driver)
    qty = holding.quantity
    wallet = @portfolio.wallet
    cash_before = wallet.cash
    price = @portfolio.share_price(@driver)

    result = Fantasy::Stock::SellShares.new(portfolio: @portfolio, driver: @driver, quantity: qty, race: @race).call

    assert result[:success]
    wallet.reload
    assert_in_delta cash_before + (price * qty), wallet.cash, 0.01

    holding.reload
    refute holding.active
    assert_equal @race, holding.closed_race
  end

  test "partially sells shares reducing quantity" do
    holding = @portfolio.active_longs.find_by(driver: @driver)
    original_qty = holding.quantity

    result = Fantasy::Stock::SellShares.new(portfolio: @portfolio, driver: @driver, quantity: 2, race: @race).call

    assert result[:success]
    holding.reload
    assert holding.active
    assert_equal original_qty - 2, holding.quantity
  end

  test "creates sell transaction" do
    Fantasy::Stock::SellShares.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call

    tx = @portfolio.transactions.where(kind: "sell", driver: @driver).last
    assert tx
    assert tx.amount.positive?
    assert_equal 1, tx.quantity
  end

  test "returns error when transfer window is closed" do
    @race.update_columns(date: 1.week.ago.to_date, time: "15:00:00")
    result = Fantasy::Stock::SellShares.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call
    assert_equal "Transfer window is closed", result[:error]
  end

  test "returns error when driver not held" do
    result = Fantasy::Stock::SellShares.new(portfolio: @portfolio, driver: drivers(:piastri), quantity: 1, race: @race).call
    assert_equal "You don't hold this driver", result[:error]
  end

  test "returns error when selling more than held" do
    result = Fantasy::Stock::SellShares.new(portfolio: @portfolio, driver: @driver, quantity: 999, race: @race).call
    assert_match(/You only hold/, result[:error])
  end

  test "returns error for invalid quantity" do
    result = Fantasy::Stock::SellShares.new(portfolio: @portfolio, driver: @driver, quantity: -1, race: @race).call
    assert_equal "Invalid quantity", result[:error]
  end
end
