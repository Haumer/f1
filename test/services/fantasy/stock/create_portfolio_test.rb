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

  test "creates a stock portfolio with zero starting capital" do
    # Create a roster portfolio first
    FantasyPortfolio.create!(user: @user, season: @season, cash: 1000.0, starting_capital: 2000.0, roster_slots: 4)

    result = Fantasy::Stock::CreatePortfolio.new(user: @user, season: @season).call

    assert result[:portfolio]
    assert_instance_of FantasyStockPortfolio, result[:portfolio]
    assert_in_delta 0, result[:portfolio].starting_capital, 0.01
  end

  test "does not change roster cash" do
    roster = FantasyPortfolio.create!(user: @user, season: @season, cash: 500.0, starting_capital: 2000.0, roster_slots: 4)
    cash_before = roster.cash

    Fantasy::Stock::CreatePortfolio.new(user: @user, season: @season).call

    roster.reload
    assert_in_delta cash_before, roster.cash, 0.1
  end

  test "returns error without roster portfolio" do
    result = Fantasy::Stock::CreatePortfolio.new(user: @user, season: @season).call
    assert_equal "You need a roster portfolio first", result[:error]
  end

  test "returns error when user already has stock portfolio" do
    result = Fantasy::Stock::CreatePortfolio.new(user: users(:codex), season: @season).call
    assert_equal "You already have a stock portfolio for this season", result[:error]
  end
end
