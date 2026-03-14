require "test_helper"

class FantasyStockPortfoliosControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:codex)
    @portfolio = fantasy_stock_portfolios(:codex_stock_2026)
    Setting.set("fantasy_stock_market", "enabled")
  end

  teardown do
    Setting.find_by(key: "fantasy_stock_market")&.destroy
  end

  test "new requires authentication" do
    get new_fantasy_stock_portfolio_path
    assert_response :redirect
  end

  test "new redirects to overview if portfolio exists" do
    sign_in @user
    get new_fantasy_stock_portfolio_path
    assert_redirected_to fantasy_overview_path(@user.username)
  end

  test "create creates a stock portfolio and redirects" do
    user = User.create!(email: "stocktest@example.com", password: "password123", username: "stocktest", terms_accepted: "1")
    season = seasons(:season_2026)
    FantasyPortfolio.create!(user: user, season: season, cash: 2000.0, starting_capital: 4000.0, roster_slots: 4)
    sign_in user
    assert_difference "FantasyStockPortfolio.count", 1 do
      post fantasy_stock_portfolios_path
    end
    assert_redirected_to fantasy_overview_path(user.username)
  end

  test "market requires authentication" do
    get market_fantasy_stock_portfolio_path(@portfolio)
    assert_response :redirect
  end

  test "market returns 200 for portfolio owner" do
    sign_in @user
    get market_fantasy_stock_portfolio_path(@portfolio)
    assert_response :success
  end

  test "leaderboard returns 200" do
    sign_in @user
    get leaderboard_fantasy_stock_portfolios_path
    assert_response :success
  end

  test "redirects to root when stock market is disabled" do
    Setting.set("fantasy_stock_market", "disabled")
    sign_in @user
    get new_fantasy_stock_portfolio_path
    assert_redirected_to root_path
  end
end
