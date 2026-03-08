require "test_helper"

class Fantasy::SellDriverTest < ActiveSupport::TestCase
  setup do
    @portfolio = fantasy_portfolios(:codex_2026)
    @driver = drivers(:verstappen)
    @race = races(:melbourne_2026)
    @race.update_columns(date: 1.week.from_now.to_date, time: "15:00:00")
    # Reset swaps so can_swap? passes
    fantasy_roster_entries(:codex_leclerc_sold).update_columns(sold_race_id: races(:bahrain_2026).id)
    # Set bought_race to an earlier round so held_races_for >= 1
    # bahrain_2025 is round 1 of 2025 season, but we need a race in the same season
    # Just set bought_race to bahrain_2025 (different season) won't help;
    # instead update the entry's bought_race round to be < latest_race round.
    # bahrain_2026 is round 1, so latest_race (with standings) is round 1.
    # We need latest_race.round > bought_race.round, so let's add standings for melbourne_2026.
    DriverStanding.create!(race: races(:melbourne_2026), driver: @driver, position: 1, points: 50, wins: 2)
    # Now latest_race = melbourne_2026 (round 2), held_races = 2 - 1 = 1 ✓
  end

  test "successfully sells a driver" do
    cash_before = @portfolio.cash
    sell_price = Fantasy::Pricing.price_for(@driver, @portfolio.season)
    fee = (sell_price * Fantasy::SellDriver::SELL_FEE).round(1)
    net = sell_price - fee

    result = Fantasy::SellDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call

    assert result[:success]
    @portfolio.reload
    refute @portfolio.has_driver?(@driver)
    assert_in_delta cash_before + net, @portfolio.cash, 0.01
  end

  test "deactivates roster entry and records sold_race" do
    Fantasy::SellDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call

    entry = @portfolio.roster_entries.find_by(driver: @driver, active: false, sold_race: @race)
    assert entry
    assert_in_delta Fantasy::Pricing.price_for(@driver, @portfolio.season), entry.sold_at_elo, 0.01
  end

  test "creates sell transaction" do
    Fantasy::SellDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call

    tx = @portfolio.transactions.where(kind: "sell", driver: @driver).last
    assert tx
    assert tx.amount.positive?
  end

  test "applies 1% sell fee" do
    price = Fantasy::Pricing.price_for(@driver, @portfolio.season)
    expected_fee = (price * 0.01).round(1)
    expected_net = price - expected_fee

    Fantasy::SellDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call

    tx = @portfolio.transactions.where(kind: "sell", driver: @driver).last
    assert_in_delta expected_net, tx.amount, 0.1
  end

  test "returns error when transfer window is closed" do
    @race.update_columns(date: 1.week.ago.to_date, time: "15:00:00")
    result = Fantasy::SellDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call
    assert_equal "Transfer window is closed", result[:error]
  end

  test "returns error when driver not on roster" do
    result = Fantasy::SellDriver.new(portfolio: @portfolio, driver: drivers(:piastri), race: @race).call
    assert_equal "Driver is not on your roster", result[:error]
  end

  test "returns error when driver not held for at least 1 race" do
    # Reset so latest_race = bahrain_2026 (round 1) = bought_race round -> held_races = 0
    DriverStanding.where(race: races(:melbourne_2026)).destroy_all
    result = Fantasy::SellDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call
    assert_equal "Must hold driver for at least 1 race", result[:error]
  end

  test "SELL_FEE is 1 percent" do
    assert_equal 0.01, Fantasy::SellDriver::SELL_FEE
  end
end
