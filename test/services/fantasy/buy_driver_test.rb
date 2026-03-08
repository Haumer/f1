require "test_helper"

class Fantasy::BuyDriverTest < ActiveSupport::TestCase
  setup do
    @portfolio = fantasy_portfolios(:codex_2026)
    @driver = drivers(:piastri)
    # Use a future race so can_trade? passes
    @race = races(:melbourne_2026)
    @race.update_columns(date: 1.week.from_now.to_date, time: "15:00:00")
  end

  test "successfully buys a driver" do
    cash_before = @portfolio.cash
    price = Fantasy::Pricing.price_for(@driver, @portfolio.season)

    result = Fantasy::BuyDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call

    assert result[:success]
    @portfolio.reload
    assert @portfolio.has_driver?(@driver)
    assert_in_delta cash_before - price, @portfolio.cash, 0.01
  end

  test "creates roster entry with correct attributes" do
    Fantasy::BuyDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call

    entry = @portfolio.roster_entries.find_by(driver: @driver)
    assert entry.active
    assert_equal @race, entry.bought_race
    assert_in_delta Fantasy::Pricing.price_for(@driver, @portfolio.season), entry.bought_at_elo, 0.01
  end

  test "creates buy transaction" do
    Fantasy::BuyDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call

    tx = @portfolio.transactions.where(kind: "buy", driver: @driver).last
    assert tx
    assert tx.amount.negative?
    assert_equal @race, tx.race
  end

  test "returns error when transfer window is closed" do
    @race.update_columns(date: 1.week.ago.to_date, time: "15:00:00")
    result = Fantasy::BuyDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call
    assert_equal "Transfer window is closed", result[:error]
  end

  test "returns error when driver already on roster" do
    result = Fantasy::BuyDriver.new(portfolio: @portfolio, driver: drivers(:verstappen), race: @race).call
    assert_equal "Driver is already on your roster", result[:error]
  end

  test "returns error when roster is full" do
    @portfolio.update_columns(roster_slots: 2) # already have 2 active
    result = Fantasy::BuyDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call
    assert_match(/Roster is full/, result[:error])
  end

  test "returns error when not enough cash" do
    @portfolio.update_columns(cash: 1.0)
    result = Fantasy::BuyDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call
    assert_match(/Not enough cash/, result[:error])
  end
end
