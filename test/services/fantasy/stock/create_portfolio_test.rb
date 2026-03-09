require "test_helper"

class Fantasy::Stock::CreatePortfolioTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "stockuser@example.com",
      password: "password123",
      username: "stockuser",
      terms_accepted: "1"
    )
    @season = seasons(:season_2026)
  end

  test "creates a stock portfolio" do
    result = Fantasy::Stock::CreatePortfolio.new(user: @user, season: @season).call

    assert result[:portfolio]
    assert_instance_of FantasyStockPortfolio, result[:portfolio]
    assert_equal @user, result[:portfolio].user
    assert_equal @season, result[:portfolio].season
  end

  test "stock portfolio cash is zero, capital added to roster wallet" do
    # Create a roster portfolio first so capital can be added to it
    roster = FantasyPortfolio.create!(user: @user, season: @season, cash: 1000.0, starting_capital: 1000.0, roster_slots: 4)
    roster_cash_before = roster.cash

    result = Fantasy::Stock::CreatePortfolio.new(user: @user, season: @season).call
    portfolio = result[:portfolio]

    assert_in_delta 0, portfolio.cash, 0.01
    roster.reload
    assert_in_delta roster_cash_before + portfolio.starting_capital, roster.cash, 0.01
  end

  test "starting capital based on avg elo times multiplier" do
    avg = Driver.where.not(elo_v2: nil)
                .joins(:season_drivers)
                .where(season_drivers: { season_id: @season.id })
                .average(:elo_v2) || 0
    expected = (avg * FantasyStockPortfolio::CAPITAL_MULTIPLIER).round(1)

    result = Fantasy::Stock::CreatePortfolio.new(user: @user, season: @season).call
    assert_in_delta expected, result[:portfolio].starting_capital, 0.1
  end

  test "returns error when user already has stock portfolio" do
    result = Fantasy::Stock::CreatePortfolio.new(user: users(:codex), season: @season).call
    assert_equal "You already have a stock portfolio for this season", result[:error]
  end
end
