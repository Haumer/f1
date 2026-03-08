require "test_helper"

class Fantasy::BuyTeamTest < ActiveSupport::TestCase
  setup do
    @portfolio = fantasy_portfolios(:codex_2026)
    @race = races(:melbourne_2026)
    @race.update_columns(date: 1.week.from_now.to_date, time: "15:00:00")
  end

  test "successfully buys a team and increases roster slots" do
    slots_before = @portfolio.roster_slots
    result = Fantasy::BuyTeam.new(portfolio: @portfolio, race: @race).call

    assert result[:success]
    @portfolio.reload
    assert_equal slots_before + FantasyPortfolio::SLOTS_PER_TEAM, @portfolio.roster_slots
  end

  test "deducts team cost from cash" do
    cash_before = @portfolio.cash
    cost = @portfolio.team_cost
    Fantasy::BuyTeam.new(portfolio: @portfolio, race: @race).call

    @portfolio.reload
    assert_in_delta cash_before - cost, @portfolio.cash, 0.01
  end

  test "returns cost in result" do
    result = Fantasy::BuyTeam.new(portfolio: @portfolio, race: @race).call
    assert result[:cost].present?
  end

  test "creates team_purchase transaction" do
    Fantasy::BuyTeam.new(portfolio: @portfolio, race: @race).call

    tx = @portfolio.transactions.where(kind: "team_purchase").last
    assert tx
    assert tx.amount.negative?
  end

  test "returns error when transfer window is closed" do
    @race.update_columns(date: 1.week.ago.to_date, time: "15:00:00")
    result = Fantasy::BuyTeam.new(portfolio: @portfolio, race: @race).call
    assert_equal "Transfer window is closed", result[:error]
  end

  test "returns error when already at max teams" do
    @portfolio.update_columns(roster_slots: FantasyPortfolio::MAX_TEAMS * FantasyPortfolio::SLOTS_PER_TEAM)
    result = Fantasy::BuyTeam.new(portfolio: @portfolio, race: @race).call
    assert_match(/Already at maximum teams/, result[:error])
  end

  test "returns error when not enough cash" do
    @portfolio.update_columns(cash: 1.0)
    result = Fantasy::BuyTeam.new(portfolio: @portfolio, race: @race).call
    assert_match(/Not enough cash/, result[:error])
  end
end
