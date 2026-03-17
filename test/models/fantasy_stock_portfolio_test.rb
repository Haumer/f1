require "test_helper"

class FantasyStockPortfolioTest < ActiveSupport::TestCase
  setup do
    @portfolio = fantasy_stock_portfolios(:codex_stock_2026)
  end

  # Associations
  test "belongs to user" do
    assert_equal users(:codex), @portfolio.user
  end

  test "belongs to season" do
    assert_equal seasons(:season_2026), @portfolio.season
  end

  test "has many holdings" do
    assert @portfolio.holdings.count >= 2
  end

  test "has many transactions" do
    assert @portfolio.transactions.count >= 1
  end

  test "has many snapshots" do
    assert_equal 2, @portfolio.snapshots.count
  end

  test "has many achievements" do
    assert @portfolio.achievements.count >= 1
  end

  # Validations
  test "validates user uniqueness per season" do
    dup = FantasyStockPortfolio.new(user: users(:codex), season: seasons(:season_2026), cash: 100, starting_capital: 100)
    refute dup.valid?
    assert_includes dup.errors[:user_id], "has already been taken"
  end

  test "cash is always zero on stock portfolio (lives on wallet)" do
    assert_in_delta 0, @portfolio.cash, 0.01
  end

  test "validates starting_capital presence" do
    @portfolio.starting_capital = nil
    refute @portfolio.valid?
  end

  # active_holdings / active_longs / active_shorts
  test "active_holdings returns only active" do
    active = @portfolio.active_holdings
    assert active.all?(&:active)
    assert_equal 2, active.count
  end

  test "active_longs returns only long active holdings" do
    longs = @portfolio.active_longs
    assert longs.all? { |h| h.direction == "long" && h.active }
    assert_equal 1, longs.count
  end

  test "active_shorts returns only short active holdings" do
    shorts = @portfolio.active_shorts
    assert shorts.all? { |h| h.direction == "short" && h.active }
    assert_equal 1, shorts.count
  end

  # position_count / positions_full?
  test "position_count returns active holdings count" do
    assert_equal 2, @portfolio.position_count
  end

  test "positions_full? returns false when under MAX_POSITIONS" do
    refute @portfolio.positions_full?
  end

  test "positions_full? returns true at MAX_POSITIONS" do
    # Add enough holdings to hit max (already have 2 active, need 10 more)
    10.times do |i|
      driver = Driver.create!(surname: "Test#{i}", driver_ref: "test#{i}")
      @portfolio.holdings.create!(
        driver: driver, quantity: 1, direction: "long",
        entry_price: 100.0, opened_race: races(:bahrain_2026), active: true
      )
    end
    assert @portfolio.positions_full?
  end

  # share_price
  test "share_price returns driver price divided by PRICE_DIVISOR" do
    price = @portfolio.share_price(drivers(:verstappen))
    expected = Fantasy::Pricing.price_for(drivers(:verstappen), seasons(:season_2026)) / FantasyStockPortfolio::PRICE_DIVISOR
    assert_in_delta expected, price, 0.01
  end

  # profit_loss
  test "profit_loss equals positions_value minus total_invested" do
    expected = (@portfolio.positions_value - @portfolio.total_invested).round(2)
    assert_in_delta expected, @portfolio.profit_loss, 0.01
  end

  # total_collateral / available_cash
  test "total_collateral sums active shorts collateral" do
    assert_in_delta 337.5, @portfolio.total_collateral, 0.01
  end

  test "available_cash is wallet cash minus total_collateral" do
    expected = (@portfolio.wallet&.cash || 0) - @portfolio.total_collateral
    assert_in_delta expected, @portfolio.available_cash, 0.01
  end

  # can_trade?
  test "can_trade? returns false for nil race" do
    refute @portfolio.can_trade?(nil)
  end

  # has_achievement?
  test "has_achievement? returns true for earned achievement" do
    assert @portfolio.has_achievement?(:first_stock_trade)
  end

  test "has_achievement? returns false for unearned achievement" do
    refute @portfolio.has_achievement?(:stock_top_1)
  end

  # value_change_since_last_race
  test "value_change_since_last_race returns diff between last two snapshots" do
    fantasy_stock_snapshots(:codex_stock_bahrain).update_columns(created_at: 1.day.ago)
    fantasy_stock_snapshots(:codex_stock_melbourne).update_columns(created_at: Time.current)
    change = @portfolio.value_change_since_last_race
    assert_in_delta 300.0, change, 0.01  # 4500 - 4200
  end

  # Constants
  test "PRICE_DIVISOR is 10" do
    assert_equal 10.0, FantasyStockPortfolio::PRICE_DIVISOR
  end

  test "MAX_POSITIONS is 12" do
    assert_equal 12, FantasyStockPortfolio::MAX_POSITIONS
  end

  test "COLLATERAL_RATIO is 0.5" do
    assert_in_delta 0.5, FantasyStockPortfolio::COLLATERAL_RATIO, 0.01
  end
end
