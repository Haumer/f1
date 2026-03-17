require "test_helper"

class Fantasy::Stock::OpenShortTest < ActiveSupport::TestCase
  setup do
    @portfolio = fantasy_stock_portfolios(:codex_stock_2026)
    @driver = drivers(:piastri) # no existing short position
    @race = races(:melbourne_2026)
    @race.update_columns(date: 1.week.from_now.to_date, time: "15:00:00")
  end

  test "successfully opens a short position" do
    result = Fantasy::Stock::OpenShort.new(portfolio: @portfolio, driver: @driver, quantity: 2, race: @race).call

    assert result[:success]
    holding = @portfolio.active_shorts.find_by(driver: @driver)
    assert holding
    assert_equal 2, holding.quantity
    assert_equal "short", holding.direction
    assert_equal @race, holding.opened_race
  end

  test "locks collateral at 50% of position value" do
    price = @portfolio.share_price(@driver)
    Fantasy::Stock::OpenShort.new(portfolio: @portfolio, driver: @driver, quantity: 3, race: @race).call

    holding = @portfolio.active_shorts.find_by(driver: @driver)
    expected = price * 3 * FantasyStockPortfolio::COLLATERAL_RATIO
    assert_in_delta expected, holding.collateral, 0.01
  end

  test "cash does not change on short open (collateral is tracked separately)" do
    wallet = @portfolio.wallet
    cash_before = wallet.cash
    Fantasy::Stock::OpenShort.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call
    wallet.reload
    assert_in_delta cash_before, wallet.cash, 0.01
  end

  test "creates short_open transaction with zero amount" do
    Fantasy::Stock::OpenShort.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call

    tx = @portfolio.transactions.where(kind: "short_open", driver: @driver).last
    assert tx
    assert_in_delta 0, tx.amount, 0.01
  end

  test "averages into existing short position" do
    Fantasy::Stock::OpenShort.new(portfolio: @portfolio, driver: @driver, quantity: 2, race: @race).call
    Fantasy::Stock::OpenShort.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call

    holding = @portfolio.active_shorts.find_by(driver: @driver)
    assert_equal 3, holding.quantity
  end

  test "returns error when transfer window is closed" do
    @race.update_columns(date: 1.week.ago.to_date, time: "15:00:00")
    result = Fantasy::Stock::OpenShort.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call
    assert_equal "Transfer window is closed", result[:error]
  end

  test "returns error for invalid quantity" do
    result = Fantasy::Stock::OpenShort.new(portfolio: @portfolio, driver: @driver, quantity: 0, race: @race).call
    assert_equal "Invalid quantity", result[:error]
  end

  test "returns error when not enough cash for collateral" do
    @portfolio.wallet.update_columns(cash: 1.0)
    result = Fantasy::Stock::OpenShort.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call
    assert_match(/Not enough credits for collateral/, result[:error])
  end
end
