require "test_helper"

class Fantasy::Stock::CloseShortTest < ActiveSupport::TestCase
  setup do
    @portfolio = fantasy_stock_portfolios(:codex_stock_2026)
    @driver = drivers(:norris) # has an active short position
    @race = races(:melbourne_2026)
    @race.update_columns(date: 1.week.from_now.to_date, time: "15:00:00")
  end

  test "successfully closes entire short position" do
    holding = @portfolio.active_shorts.find_by(driver: @driver)
    qty = holding.quantity

    result = Fantasy::Stock::CloseShort.new(portfolio: @portfolio, driver: @driver, quantity: qty, race: @race).call

    assert result[:success]
    holding.reload
    refute holding.active
    assert_equal @race, holding.closed_race
    assert_in_delta 0, holding.collateral, 0.01
  end

  test "partially closes short reducing quantity" do
    holding = @portfolio.active_shorts.find_by(driver: @driver)
    original_qty = holding.quantity
    original_collateral = holding.collateral

    result = Fantasy::Stock::CloseShort.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call

    assert result[:success]
    holding.reload
    assert holding.active
    assert_equal original_qty - 1, holding.quantity
    assert holding.collateral < original_collateral
  end

  test "adjusts cash by P&L" do
    cash_before = @portfolio.cash
    holding = @portfolio.active_shorts.find_by(driver: @driver)
    current_price = @portfolio.share_price(@driver)
    pnl = (holding.entry_price - current_price) * holding.quantity

    Fantasy::Stock::CloseShort.new(portfolio: @portfolio, driver: @driver, quantity: holding.quantity, race: @race).call

    @portfolio.reload
    expected = [cash_before + pnl, 0].max
    assert_in_delta expected, @portfolio.cash, 0.01
  end

  test "creates short_close transaction" do
    Fantasy::Stock::CloseShort.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call

    tx = @portfolio.transactions.where(kind: "short_close", driver: @driver).last
    assert tx
  end

  test "returns error when transfer window is closed" do
    @race.update_columns(date: 1.week.ago.to_date, time: "15:00:00")
    result = Fantasy::Stock::CloseShort.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call
    assert_equal "Transfer window is closed", result[:error]
  end

  test "returns error when no short position exists" do
    result = Fantasy::Stock::CloseShort.new(portfolio: @portfolio, driver: drivers(:piastri), quantity: 1, race: @race).call
    assert_equal "No short position on this driver", result[:error]
  end

  test "returns error when closing more than held" do
    result = Fantasy::Stock::CloseShort.new(portfolio: @portfolio, driver: @driver, quantity: 999, race: @race).call
    assert_match(/You only have/, result[:error])
  end

  test "returns error for invalid quantity" do
    result = Fantasy::Stock::CloseShort.new(portfolio: @portfolio, driver: @driver, quantity: 0, race: @race).call
    assert_equal "Invalid quantity", result[:error]
  end
end
