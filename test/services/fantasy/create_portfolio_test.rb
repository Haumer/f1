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

  test "cash is half of starting_capital" do
    result = Fantasy::CreatePortfolio.new(user: @user, season: @season).call
    portfolio = result[:portfolio]
    assert_in_delta portfolio.starting_capital / 2.0, portfolio.cash, 0.1
  end

  test "starting_capital is fixed at 9450" do
    result = Fantasy::CreatePortfolio.new(user: @user, season: @season).call
    assert_in_delta 9450.0, result[:portfolio].starting_capital, 0.01
  end

  test "returns error when user already has portfolio for season" do
    result = Fantasy::CreatePortfolio.new(user: users(:codex), season: @season).call
    assert_equal "You already have a portfolio for this season", result[:error]
  end

  test "STARTING_CAPITAL is 9450" do
    assert_in_delta 9450.0, Fantasy::CreatePortfolio::STARTING_CAPITAL, 0.01
  end
end
