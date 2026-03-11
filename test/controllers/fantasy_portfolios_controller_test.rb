require "test_helper"

class FantasyPortfoliosControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:codex)
    @portfolio = fantasy_portfolios(:codex_2026)
  end

  # ── Public routes ──

  test "overview returns 200 for logged-in owner" do
    sign_in @user
    get fantasy_overview_path(@user.username)
    assert_response :success
  end

  test "overview returns 200 for logged-out visitor" do
    @user.update_columns(public_profile: true)
    get fantasy_overview_path(@user.username)
    assert_response :success
  end

  test "leaderboard returns 200" do
    get leaderboard_fantasy_portfolios_path
    assert_response :success
  end

  test "combined_leaderboard returns 200" do
    get combined_leaderboard_path
    assert_response :success
  end

  # ── Authenticated routes ──

  test "new requires authentication" do
    get new_fantasy_portfolio_path
    assert_response :redirect
  end

  test "new returns 200 for logged-in user without portfolio" do
    user = User.create!(email: "newuser@example.com", password: "password123", username: "newuser", terms_accepted: "1")
    sign_in user
    get new_fantasy_portfolio_path
    assert_response :success
  end

  test "new redirects to overview if portfolio already exists" do
    sign_in @user
    get new_fantasy_portfolio_path
    assert_redirected_to fantasy_overview_path(@user.username)
  end

  test "create creates a portfolio and redirects" do
    user = User.create!(email: "createtest@example.com", password: "password123", username: "createtest", terms_accepted: "1")
    sign_in user
    assert_difference "FantasyPortfolio.count", 1 do
      post fantasy_portfolios_path
    end
    assert_redirected_to fantasy_overview_path(user.username)
  end

  test "market requires authentication" do
    get market_fantasy_portfolio_path(@portfolio)
    assert_response :redirect
  end

  test "market returns 200 for portfolio owner" do
    sign_in @user
    get market_fantasy_portfolio_path(@portfolio)
    assert_response :success
  end

  # ── Trading ──

  test "buy requires authentication" do
    post buy_fantasy_portfolio_path(@portfolio), params: { driver_id: drivers(:piastri).id }
    assert_response :redirect
  end

  test "sell requires authentication" do
    post sell_fantasy_portfolio_path(@portfolio), params: { driver_id: drivers(:verstappen).id }
    assert_response :redirect
  end

  # ── Toggle public ──

  test "toggle_public requires authentication" do
    post toggle_public_profile_path
    assert_response :redirect
  end

  test "toggle_public flips profile visibility" do
    sign_in @user
    @user.update_columns(public_profile: false)
    post toggle_public_profile_path
    assert @user.reload.public_profile?
  end

  # ── Roster/stocks redirects ──

  test "roster redirects to overview" do
    get fantasy_roster_path(@user.username)
    assert_redirected_to fantasy_overview_path(@user.username)
  end

  test "stocks redirects to overview" do
    get fantasy_stocks_path(@user.username)
    assert_redirected_to fantasy_overview_path(@user.username)
  end
end
