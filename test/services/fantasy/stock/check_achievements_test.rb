require "test_helper"

class Fantasy::Stock::CheckAchievementsTest < ActiveSupport::TestCase
  setup do
    @portfolio = fantasy_stock_portfolios(:codex_stock_2026)
  end

  test "returns array of earned achievements" do
    result = Fantasy::Stock::CheckAchievements.new(portfolio: @portfolio).call
    assert_kind_of Array, result
  end

  test "awards first_stock_trade when trades exist (idempotent)" do
    # Already has first_stock_trade in fixtures, should not re-award
    result = Fantasy::Stock::CheckAchievements.new(portfolio: @portfolio).call
    refute result.any? { |a| a&.key == "first_stock_trade" }
  end

  test "awards first_long when long holdings exist" do
    # first_long is in fixtures, remove it so it can be re-earned
    @portfolio.achievements.where(key: "first_long").destroy_all
    result = Fantasy::Stock::CheckAchievements.new(portfolio: @portfolio).call
    keys = result.compact.map(&:key)
    assert_includes keys, "first_long"
  end

  test "awards first_short when short holdings exist" do
    @portfolio.achievements.where(key: "first_short").destroy_all
    result = Fantasy::Stock::CheckAchievements.new(portfolio: @portfolio).call
    keys = result.compact.map(&:key)
    assert_includes keys, "first_short"
  end

  test "awards first_stock_profit when portfolio is profitable" do
    result = Fantasy::Stock::CheckAchievements.new(portfolio: @portfolio).call
    keys = result.compact.map(&:key)
    # Portfolio has 3000 cash + holdings value vs 2000 starting capital, should be profitable
    assert_includes keys, "first_stock_profit"
  end

  test "does not duplicate achievements" do
    Fantasy::Stock::CheckAchievements.new(portfolio: @portfolio).call
    count = @portfolio.achievements.count
    Fantasy::Stock::CheckAchievements.new(portfolio: @portfolio).call
    assert_equal count, @portfolio.achievements.count
  end

  test "awards leaderboard achievements based on snapshot rank" do
    @portfolio.snapshots.order(created_at: :desc).first&.update!(rank: 1)
    result = Fantasy::Stock::CheckAchievements.new(portfolio: @portfolio).call
    keys = result.compact.map(&:key)
    assert_includes keys, "stock_top_1"
    assert_includes keys, "stock_top_3"
  end

  test "awards profitable_short when closed short has profit" do
    # The closed leclerc holding — set entry > current to simulate profit
    closed = fantasy_stock_holdings(:codex_lec_closed)
    # gain_loss for short = (entry - current) * qty; to be profitable for a closed short
    # it needs to have been closed at a lower price. Since it's closed, current_price
    # still uses live share_price. Let's set entry_price very high.
    closed.update_columns(direction: "short", entry_price: 9999.0)

    result = Fantasy::Stock::CheckAchievements.new(portfolio: @portfolio).call
    keys = result.compact.map(&:key)
    assert_includes keys, "profitable_short"
  end
end
