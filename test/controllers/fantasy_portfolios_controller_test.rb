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

  # ── Combined leaderboard with stock timing scenarios ──

  test "combined leaderboard renders for user with stock portfolio created after first snapshot" do
    Setting.set("fantasy_stock_market", "enabled")
    get combined_leaderboard_path
    assert_response :success
  ensure
    Setting.find_by(key: "fantasy_stock_market")&.destroy
  end

  test "combined leaderboard renders for single-snapshot late-stock user without 500 error" do
    Setting.set("fantasy_stock_market", "enabled")
    # Delete latejoin's melbourne snapshot → single snapshot, stock created after it
    fantasy_snapshots(:latejoin_melbourne).destroy!
    get combined_leaderboard_path
    assert_response :success
  ensure
    Setting.find_by(key: "fantasy_stock_market")&.destroy
  end

  # ── Overview chart start value ──

  test "overview renders for user with stock portfolio created after first snapshot" do
    sign_in users(:latejoin)
    get fantasy_overview_path(users(:latejoin).username)
    assert_response :success
  end

  test "overview renders for user with stock portfolio predating first snapshot" do
    sign_in @user
    stock_p = fantasy_stock_portfolios(:codex_stock_2026)
    bahrain_snap = fantasy_snapshots(:codex_bahrain)
    stock_p.update_columns(created_at: bahrain_snap.created_at - 1.day)
    get fantasy_overview_path(@user.username)
    assert_response :success
  end
end
