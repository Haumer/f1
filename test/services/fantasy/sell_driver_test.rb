require "test_helper"

class Fantasy::SellDriverTest < ActiveSupport::TestCase
  setup do
    @portfolio = fantasy_portfolios(:codex_2026)
    @driver = drivers(:verstappen)
    # Use melbourne as the trade race (future date so transfer window is open)
    @race = races(:melbourne_2026)
    @race.update_columns(date: 1.week.from_now.to_date, time: "15:00:00")
    # Reset swaps so can_swap? passes
    fantasy_roster_entries(:codex_leclerc_sold).update_columns(sold_race_id: races(:bahrain_2026).id)
    # Ensure bahrain_2026 (round 1) is in the past with standings so latest_race = round 1
    races(:bahrain_2026).update_columns(date: 1.week.ago.to_date)
    DriverStanding.find_or_create_by!(race: races(:bahrain_2026), driver: @driver) do |ds|
      ds.position = 1; ds.points = 50; ds.wins = 2
    end
    # Set bought_race to round 0 so held_races >= 1
    fantasy_roster_entries(:codex_verstappen).update_columns(bought_race_id: nil)
    # Create a round-0 race for bought_race
    r0 = Race.create!(year: 2026, round: 0, date: 2.weeks.ago.to_date, time: "15:00:00",
                       circuit: circuits(:bahrain), season: seasons(:season_2026))
    fantasy_roster_entries(:codex_verstappen).update_columns(bought_race_id: r0.id)
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
    # Set bought_race = bahrain_2026 (round 1) = latest_race -> held_races = 0
    fantasy_roster_entries(:codex_verstappen).update_columns(bought_race_id: races(:bahrain_2026).id)
    result = Fantasy::SellDriver.new(portfolio: @portfolio, driver: @driver, race: @race).call
    assert_equal "Must hold driver for at least 1 race", result[:error]
  end

  test "SELL_FEE is 1 percent" do
    assert_equal 0.01, Fantasy::SellDriver::SELL_FEE
  end
end
