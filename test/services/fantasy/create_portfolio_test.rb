require "test_helper"

class Fantasy::CreatePortfolioTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "newuser@example.com",
      password: "password123",
      username: "newuser",
      terms_accepted: "1"
    )
    @season = seasons(:season_2026)
  end

  test "creates a portfolio for user and season" do
    result = Fantasy::CreatePortfolio.new(user: @user, season: @season).call

    assert result[:portfolio]
    assert_instance_of FantasyPortfolio, result[:portfolio]
    assert_equal @user, result[:portfolio].user
    assert_equal @season, result[:portfolio].season
  end

  test "sets cash equal to starting_capital" do
    result = Fantasy::CreatePortfolio.new(user: @user, season: @season).call
    portfolio = result[:portfolio]
    assert_in_delta portfolio.starting_capital, portfolio.cash, 0.01
  end

  test "starting_capital is based on average elo times multiplier" do
    avg = Driver.where.not(elo_v2: nil)
                .joins(:season_drivers)
                .where(season_drivers: { season_id: @season.id })
                .average(:elo_v2) || 0
    expected = (avg * Fantasy::CreatePortfolio::CAPITAL_MULTIPLIER).round(1)

    result = Fantasy::CreatePortfolio.new(user: @user, season: @season).call
    assert_in_delta expected, result[:portfolio].starting_capital, 0.1
  end

  test "returns error when user already has portfolio for season" do
    result = Fantasy::CreatePortfolio.new(user: users(:codex), season: @season).call
    assert_equal "You already have a portfolio for this season", result[:error]
  end

  test "CAPITAL_MULTIPLIER is 2.2" do
    assert_in_delta 2.2, Fantasy::CreatePortfolio::CAPITAL_MULTIPLIER, 0.01
  end
end
