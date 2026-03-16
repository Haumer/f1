require "test_helper"

class FantasyStockPortfoliosControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:codex)
    @portfolio = fantasy_stock_portfolios(:codex_stock_2026)
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
end
