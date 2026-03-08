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

  test "has many roster_entries" do
    assert @portfolio.roster_entries.count >= 2
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
    dup = FantasyPortfolio.new(user: users(:codex), season: seasons(:season_2026), cash: 100, starting_capital: 100, roster_slots: 2)
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

  # active_roster_entries
  test "active_roster_entries returns only active entries" do
    active = @portfolio.active_roster_entries
    assert active.all?(&:active)
    assert_equal 2, active.count
  end

  # active_drivers
  test "active_drivers returns drivers on active roster" do
    drivers = @portfolio.active_drivers
    assert_includes drivers, drivers(:verstappen)
    assert_includes drivers, drivers(:norris)
    refute_includes drivers, drivers(:leclerc)
  end

  # portfolio_value
  test "portfolio_value includes cash plus driver prices" do
    value = @portfolio.portfolio_value
    expected_drivers_value = Fantasy::Pricing.price_for(drivers(:verstappen), seasons(:season_2026)) +
                             Fantasy::Pricing.price_for(drivers(:norris), seasons(:season_2026))
    assert_in_delta @portfolio.cash + expected_drivers_value, value, 0.01
  end

  # profit_loss
  test "profit_loss is portfolio_value minus starting_capital" do
    expected = @portfolio.portfolio_value - @portfolio.starting_capital
    assert_in_delta expected, @portfolio.profit_loss, 0.01
  end

  # can_trade?
  test "can_trade? returns false for nil race" do
    refute @portfolio.can_trade?(nil)
  end

  test "can_trade? returns true for future race" do
    race = races(:melbourne_2026)
    # melbourne_2026 has time set, so starts_at should work
    if race.starts_at && race.starts_at > Time.current + 1.minute
      assert @portfolio.can_trade?(race)
    end
  end

  # roster_full?
  test "roster_full? returns false when under limit" do
    # 2 active, 4 roster_slots
    refute @portfolio.roster_full?
  end

  test "roster_full? returns true when at limit" do
    @portfolio.roster_slots = 2
    assert @portfolio.roster_full?
  end

  # max_swaps_per_race
  test "max_swaps_per_race is roster_slots divided by SLOTS_PER_TEAM" do
    assert_equal 2, @portfolio.max_swaps_per_race  # 4 / 2
  end

  # teams_owned
  test "teams_owned is roster_slots divided by SLOTS_PER_TEAM" do
    assert_equal 2, @portfolio.teams_owned
  end

  # can_buy_team?
  test "can_buy_team? returns true when under MAX_TEAMS" do
    assert @portfolio.can_buy_team?
  end

  test "can_buy_team? returns false at MAX_TEAMS" do
    @portfolio.roster_slots = FantasyPortfolio::MAX_TEAMS * FantasyPortfolio::SLOTS_PER_TEAM
    refute @portfolio.can_buy_team?
  end

  # has_driver?
  test "has_driver? returns true for active roster driver" do
    assert @portfolio.has_driver?(drivers(:verstappen))
  end

  test "has_driver? returns false for non-roster driver" do
    refute @portfolio.has_driver?(drivers(:piastri))
  end

  test "has_driver? returns false for sold driver" do
    refute @portfolio.has_driver?(drivers(:leclerc))
  end

  # has_achievement?
  test "has_achievement? returns true for earned achievement" do
    assert @portfolio.has_achievement?(:first_trade)
  end

  test "has_achievement? returns false for unearned achievement" do
    refute @portfolio.has_achievement?(:ten_trades)
  end

  # Constants
  test "STARTING_SLOTS is 2" do
    assert_equal 2, FantasyPortfolio::STARTING_SLOTS
  end

  test "MAX_TEAMS is 3" do
    assert_equal 3, FantasyPortfolio::MAX_TEAMS
  end

  test "MAX_ROSTER_SIZE is 6" do
    assert_equal 6, FantasyPortfolio::MAX_ROSTER_SIZE
  end

  # value_change_since_last_race
  test "value_change_since_last_race returns diff between last two snapshots" do
    # Ensure ordering is deterministic by touching created_at
    fantasy_snapshots(:codex_bahrain).update_columns(created_at: 1.day.ago)
    fantasy_snapshots(:codex_melbourne).update_columns(created_at: Time.current)
    change = @portfolio.value_change_since_last_race
    assert_in_delta 300.0, change, 0.01  # 8800 - 8500
  end

  # swaps_this_race
  test "swaps_this_race counts sold entries for that race" do
    count = @portfolio.swaps_this_race(races(:melbourne_2026))
    assert_equal 1, count  # codex_leclerc_sold was sold at melbourne
  end

  test "swaps_this_race returns 0 for race with no swaps" do
    assert_equal 0, @portfolio.swaps_this_race(races(:bahrain_2025))
  end
end
