require "test_helper"

class CheckAchievementsJobTest < ActiveSupport::TestCase
  test "job is enqueued on default queue" do
    assert_equal "default", CheckAchievementsJob.new.queue_name
  end

  test "perform processes roster portfolio achievements" do
    portfolio = fantasy_portfolios(:codex_2026)
    race = races(:bahrain_2026)

    # Should not raise
    CheckAchievementsJob.new.perform(
      portfolio_type: "roster",
      portfolio_id: portfolio.id,
      race_id: race.id
    )
  end

  test "perform processes stock portfolio achievements" do
    portfolio = fantasy_stock_portfolios(:codex_stock_2026)

    CheckAchievementsJob.new.perform(
      portfolio_type: "stock",
      portfolio_id: portfolio.id
    )
  end

  test "perform silently returns for missing portfolio" do
    CheckAchievementsJob.new.perform(
      portfolio_type: "roster",
      portfolio_id: -1
    )
  end

  test "perform silently returns for missing stock portfolio" do
    CheckAchievementsJob.new.perform(
      portfolio_type: "stock",
      portfolio_id: -1
    )
  end
end
