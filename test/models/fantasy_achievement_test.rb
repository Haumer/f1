require "test_helper"

class FantasyAchievementTest < ActiveSupport::TestCase
  setup do
    @achievement = fantasy_achievements(:codex_first_profit)
  end

  test "belongs to fantasy_portfolio" do
    assert_equal fantasy_portfolios(:codex_2026), @achievement.fantasy_portfolio
  end

  test "validates key presence" do
    a = FantasyAchievement.new(fantasy_portfolio: fantasy_portfolios(:codex_2026), key: nil, tier: "bronze")
    refute a.valid?
    assert_includes a.errors[:key], "can't be blank"
  end

  test "validates key uniqueness per portfolio" do
    dup = FantasyAchievement.new(
      fantasy_portfolio: fantasy_portfolios(:codex_2026),
      key: "first_profit",
      tier: "silver"
    )
    refute dup.valid?
    assert_includes dup.errors[:key], "has already been taken"
  end

  test "validates tier inclusion" do
    a = FantasyAchievement.new(
      fantasy_portfolio: fantasy_portfolios(:codex_2026),
      key: "new_achievement",
      tier: "platinum"
    )
    refute a.valid?
    assert_includes a.errors[:tier], "is not included in the list"
  end

  test "all valid tiers pass validation" do
    %w[bronze silver gold].each do |tier|
      a = FantasyAchievement.new(
        fantasy_portfolio: fantasy_portfolios(:codex_2026),
        key: "test_#{tier}",
        tier: tier
      )
      assert a.valid?, "Expected tier #{tier} to be valid"
    end
  end

  test "definition returns hash for known key" do
    defn = @achievement.definition
    assert_equal "In the Money", defn[:name]
    assert_equal "bronze", defn[:tier]
  end

  test "definition returns empty hash for unknown key" do
    @achievement.key = "nonexistent_key"
    assert_equal({}, @achievement.definition)
  end

  test "name returns definition name" do
    assert_equal "In the Money", @achievement.name
  end

  test "name falls back to humanized key" do
    @achievement.key = "unknown_key"
    assert_equal "Unknown key", @achievement.name
  end

  test "description returns definition description" do
    assert_equal "Portfolio value exceeded starting capital", @achievement.description
  end

  test "description returns empty string for unknown key" do
    @achievement.key = "unknown_key"
    assert_equal "", @achievement.description
  end

  test "icon returns definition icon" do
    assert_equal "fa-arrow-trend-up", @achievement.icon
  end

  test "icon returns fa-star for unknown key" do
    @achievement.key = "unknown_key"
    assert_equal "fa-star", @achievement.icon
  end

  test "DEFINITIONS covers all expected achievement types" do
    expected_keys = %i[first_profit profit_500 profit_1000
                       all_time_high streak_3
                       top_3 top_1 early_adopter]
    expected_keys.each do |key|
      assert FantasyAchievement::DEFINITIONS.key?(key), "Missing definition for #{key}"
    end
  end
end
