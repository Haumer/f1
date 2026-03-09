require "test_helper"

class Fantasy::Stock::BuySharesTest < ActiveSupport::TestCase
  setup do
    @portfolio = fantasy_stock_portfolios(:codex_stock_2026)
    @driver = drivers(:piastri)
    @race = races(:melbourne_2026)
    @race.update_columns(date: 1.week.from_now.to_date, time: "15:00:00")
  end

  test "successfully buys shares" do
    wallet = @portfolio.wallet
    cash_before = wallet.cash
    price = @portfolio.share_price(@driver)
    qty = 2

    result = Fantasy::Stock::BuyShares.new(portfolio: @portfolio, driver: @driver, quantity: qty, race: @race).call

    assert result[:success]
    wallet.reload
    assert_in_delta cash_before - (price * qty), wallet.cash, 0.01
  end

  test "creates long holding" do
    Fantasy::Stock::BuyShares.new(portfolio: @portfolio, driver: @driver, quantity: 3, race: @race).call

    holding = @portfolio.active_longs.find_by(driver: @driver)
    assert holding
    assert_equal 3, holding.quantity
    assert_equal "long", holding.direction
    assert_equal @race, holding.opened_race
  end

  test "creates buy transaction" do
    Fantasy::Stock::BuyShares.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call

    tx = @portfolio.transactions.where(kind: "buy", driver: @driver).last
    assert tx
    assert tx.amount.negative?
    assert_equal 1, tx.quantity
  end

  test "averages into existing position" do
    # First buy
    Fantasy::Stock::BuyShares.new(portfolio: @portfolio, driver: @driver, quantity: 2, race: @race).call
    first_price = @portfolio.share_price(@driver)

    # Second buy adds to position
    result = Fantasy::Stock::BuyShares.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call
    assert result[:success]

    holding = @portfolio.active_longs.find_by(driver: @driver)
    assert_equal 3, holding.quantity
    # Average price should be weighted average
    expected_avg = ((first_price * 2) + (first_price * 1)) / 3
    assert_in_delta expected_avg, holding.entry_price, 0.01
  end

  test "returns error when transfer window is closed" do
    @race.update_columns(date: 1.week.ago.to_date, time: "15:00:00")
    result = Fantasy::Stock::BuyShares.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call
    assert_equal "Transfer window is closed", result[:error]
  end

  test "returns error for invalid quantity" do
    result = Fantasy::Stock::BuyShares.new(portfolio: @portfolio, driver: @driver, quantity: 0, race: @race).call
    assert_equal "Invalid quantity", result[:error]
  end

  test "returns error when not enough cash" do
    @portfolio.wallet.update_columns(cash: 1.0)
    result = Fantasy::Stock::BuyShares.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call
    assert_match(/Not enough cash/, result[:error])
  end

  test "returns error when positions full and no existing position" do
    # Fill up to max positions
    4.times do |i|
      d = Driver.create!(surname: "Fill#{i}", driver_ref: "fill#{i}")
      @portfolio.holdings.create!(driver: d, quantity: 1, direction: "long", entry_price: 100, opened_race: @race, active: true)
    end
    result = Fantasy::Stock::BuyShares.new(portfolio: @portfolio, driver: @driver, quantity: 1, race: @race).call
    assert_match(/Too many positions/, result[:error])
  end
end
