require "test_helper"

class FantasyStockAchievementTest < ActiveSupport::TestCase
  setup do
    @achievement = fantasy_stock_achievements(:codex_first_stock_trade)
  end

  test "belongs to fantasy_stock_portfolio" do
    assert_equal fantasy_stock_portfolios(:codex_stock_2026), @achievement.fantasy_stock_portfolio
  end

  test "validates key presence" do
    a = FantasyStockAchievement.new(fantasy_stock_portfolio: fantasy_stock_portfolios(:codex_stock_2026), key: nil, tier: "bronze")
    refute a.valid?
    assert_includes a.errors[:key], "can't be blank"
  end

  test "validates key uniqueness per portfolio" do
    dup = FantasyStockAchievement.new(
      fantasy_stock_portfolio: fantasy_stock_portfolios(:codex_stock_2026),
      key: "first_stock_trade",
      tier: "silver"
    )
    refute dup.valid?
    assert_includes dup.errors[:key], "has already been taken"
  end

  test "validates tier inclusion" do
    a = FantasyStockAchievement.new(
      fantasy_stock_portfolio: fantasy_stock_portfolios(:codex_stock_2026),
      key: "new_key",
      tier: "diamond"
    )
    refute a.valid?
  end

  test "definition returns hash for known key" do
    defn = @achievement.definition
    assert_equal "First Trade", defn[:name]
    assert_equal "bronze", defn[:tier]
  end

  test "definition returns empty hash for unknown key" do
    @achievement.key = "nonexistent"
    assert_equal({}, @achievement.definition)
  end

  test "name returns definition name" do
    assert_equal "First Trade", @achievement.name
  end

  test "name falls back to humanized key" do
    @achievement.key = "mystery_key"
    assert_equal "Mystery key", @achievement.name
  end

  test "description returns definition description" do
    assert_equal "Made your first stock transaction", @achievement.description
  end

  test "icon returns definition icon" do
    assert_equal "fa-handshake", @achievement.icon
  end

  test "icon returns fa-star for unknown key" do
    @achievement.key = "mystery_key"
    assert_equal "fa-star", @achievement.icon
  end

  test "DEFINITIONS covers all expected stock achievement types" do
    expected_keys = %i[first_stock_trade five_stock_trades ten_stock_trades first_long first_short
                       max_positions first_stock_profit stock_profit_500 stock_profit_1000
                       profitable_short first_dividend stock_top_3 stock_top_1]
    expected_keys.each do |key|
      assert FantasyStockAchievement::DEFINITIONS.key?(key), "Missing definition for #{key}"
    end
  end
end
