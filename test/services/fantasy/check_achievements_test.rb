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

  test "awards first_trade when portfolio has trades" do
    # first_trade already exists in fixtures, so it should be skipped (idempotent)
    result = Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    refute result.any? { |a| a&.key == "first_trade" }
  end

  test "awards trade count achievements" do
    # Remove existing first_trade so it can be re-earned
    @portfolio.achievements.where(key: "first_trade").destroy_all

    result = Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    keys = result.compact.map(&:key)
    assert_includes keys, "first_trade"
  end

  test "awards first_profit when portfolio is profitable" do
    # Remove existing and ensure portfolio is profitable
    @portfolio.achievements.where(key: "first_profit").destroy_all

    result = Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    keys = result.compact.map(&:key)
    assert_includes keys, "first_profit"
  end

  test "awards driver_won when rostered driver won the race" do
    # verstappen won bahrain_2026 (position_order: 1) and is on roster
    result = Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    keys = result.compact.map(&:key)
    assert_includes keys, "driver_won"
  end

  test "awards driver_podium when rostered driver is on podium" do
    result = Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    keys = result.compact.map(&:key)
    assert_includes keys, "driver_podium"
  end

  test "awards driver_elo_surge when driver gains 40+ elo" do
    # Set up a big elo gain for verstappen
    rr = race_results(:bahrain_2026_verstappen)
    rr.update_columns(old_elo_v2: 2300.0, new_elo_v2: 2350.0)  # +50

    result = Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    keys = result.compact.map(&:key)
    assert_includes keys, "driver_elo_surge"
  end

  test "does not duplicate achievements" do
    Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    count_after_first = @portfolio.achievements.count
    Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    assert_equal count_after_first, @portfolio.achievements.count
  end

  test "awards second_team when portfolio has 2 teams" do
    result = Fantasy::CheckAchievements.new(portfolio: @portfolio, race: @race).call
    keys = result.compact.map(&:key)
    assert_includes keys, "second_team"  # roster_slots=4 means 2 teams
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
