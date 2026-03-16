require "test_helper"

class Fantasy::CheckAchievementsTest < ActiveSupport::TestCase
  setup do
    @portfolio = fantasy_portfolios(:codex_2026)
    @race = races(:bahrain_2026)
  end

  test "returns array of earned achievements" do
    result = Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    assert_kind_of Array, result
  end

  test "awards first_profit when portfolio is profitable" do
    # Remove existing and ensure portfolio is profitable
    @portfolio.achievements.where(key: "first_profit").destroy_all
    # Set cash high enough that total_return > 0 (portfolio_value - STARTING_CAPITAL)
    @portfolio.update_columns(cash: Fantasy::CreatePortfolio::STARTING_CAPITAL + 100)

    result = Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    keys = result.compact.map(&:key)
    assert_includes keys, "first_profit"
  end

  test "does not duplicate achievements" do
    Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    count_after_first = @portfolio.achievements.count
    Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    assert_equal count_after_first, @portfolio.achievements.count
  end

  test "awards leaderboard rank achievements" do
    # Give portfolio a rank-1 snapshot
    @portfolio.snapshots.order(created_at: :desc).first&.update!(rank: 1)

    result = Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    keys = result.compact.map(&:key)
    assert_includes keys, "top_1"
    assert_includes keys, "top_3"
  end

  test "check_streak awards streak_3 with 4+ increasing snapshots" do
    # Clear existing snapshots and create fresh ones with increasing values
    @portfolio.snapshots.destroy_all
    races = [races(:bahrain_2025), races(:melbourne_2025), races(:bahrain_2026), races(:melbourne_2026)]
    [7000, 7500, 8000, 8500].each_with_index do |val, i|
      @portfolio.snapshots.create!(
        race: races[i],
        value: val, cash: 5000.0,
        created_at: (4 - i).days.ago
      )
    end

    result = Fantasy::CheckAchievements.new(portfolio: @portfolio).call
    keys = result.compact.map(&:key)
    assert_includes keys, "streak_3"
  end

  test "check_all_time_high awards when latest snapshot is max" do
    @portfolio.snapshots.destroy_all
    @portfolio.snapshots.create!(race: races(:bahrain_2025), value: 8000, cash: 5000, created_at: 2.days.ago)
    @portfolio.snapshots.create!(race: races(:bahrain_2026), value: 9000, cash: 5000, created_at: 1.day.ago)

    result = Fantasy::CheckAchievements.new(portfolio: @portfolio).call
    keys = result.compact.map(&:key)
    assert_includes keys, "all_time_high"
  end
end
