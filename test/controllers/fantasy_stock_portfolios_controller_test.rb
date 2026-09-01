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

  # /stocks/leaderboard was linked from nowhere and ranked on stock-only value,
  # so it published different figures from /leaderboard for the same player.
  # Folded into the canonical standings page.
  test "legacy stock leaderboard redirects to the combined leaderboard" do
    sign_in @user
    get "/stocks/leaderboard"
    assert_redirected_to combined_leaderboard_path
  end
end
