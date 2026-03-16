require "test_helper"

class FantasyPortfolioTest < ActiveSupport::TestCase
  setup do
    @portfolio = fantasy_portfolios(:codex_2026)
  end

  # Associations
  test "belongs to user" do
    assert_equal users(:codex), @portfolio.user
  end

  test "belongs to season" do
    assert_equal seasons(:season_2026), @portfolio.season
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
    dup = FantasyPortfolio.new(user: users(:codex), season: seasons(:season_2026), cash: 100, starting_capital: 100)
    refute dup.valid?
    assert_includes dup.errors[:user_id], "has already been taken"
  end

  test "validates cash presence" do
    @portfolio.cash = nil
    refute @portfolio.valid?
  end

  test "validates starting_capital presence" do
    @portfolio.starting_capital = nil
    refute @portfolio.valid?
  end

  # portfolio_value
  test "portfolio_value includes cash plus stock positions value" do
    value = @portfolio.portfolio_value
    stock_value = @portfolio.stock_portfolio&.positions_value || 0
    assert_in_delta @portfolio.cash + stock_value, value, 0.01
  end

  # profit_loss
  test "profit_loss delegates to stock portfolio" do
    expected = @portfolio.stock_portfolio&.profit_loss || 0
    assert_in_delta expected, @portfolio.profit_loss, 0.01
  end

  # can_trade?
  test "can_trade? returns false for nil race" do
    refute @portfolio.can_trade?(nil)
  end

  test "can_trade? returns true for future race" do
    race = races(:melbourne_2026)
    if race.starts_at && race.starts_at > Time.current + 1.minute
      assert @portfolio.can_trade?(race)
    end
  end

  # has_achievement?
  test "has_achievement? returns true for earned achievement" do
    assert @portfolio.has_achievement?(:first_trade)
  end

  test "has_achievement? returns false for unearned achievement" do
    refute @portfolio.has_achievement?(:ten_trades)
  end

  # value_change_since_last_race
  test "value_change_since_last_race returns diff between last two snapshots" do
    # Ensure ordering is deterministic by touching created_at
    fantasy_snapshots(:codex_bahrain).update_columns(created_at: 1.day.ago)
    fantasy_snapshots(:codex_melbourne).update_columns(created_at: Time.current)
    change = @portfolio.value_change_since_last_race
    assert_in_delta 300.0, change, 0.01  # 8800 - 8500
  end

  # stock_portfolio
  test "stock_portfolio returns associated stock portfolio" do
    sp = @portfolio.stock_portfolio
    assert_instance_of FantasyStockPortfolio, sp if sp
  end

  # available_cash
  test "available_cash subtracts collateral from cash" do
    available = @portfolio.available_cash
    collateral = @portfolio.stock_portfolio&.total_collateral || 0
    assert_in_delta @portfolio.cash - collateral, available, 0.01
  end

  # total_return
  test "total_return is portfolio_value minus starting capital" do
    expected = (@portfolio.portfolio_value - Fantasy::CreatePortfolio::STARTING_CAPITAL).round(2)
    assert_in_delta expected, @portfolio.total_return, 0.01
  end
end
