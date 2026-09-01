require "test_helper"

class FantasyPortfoliosControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:codex)
    @portfolio = fantasy_portfolios(:codex_2026)
  end

  # -- Public routes --

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

  # /fantasy/leaderboard was unlinked and shipped a <title> byte-identical to
  # /leaderboard. Folded into the canonical standings page.
  test "legacy fantasy leaderboard redirects to the combined leaderboard" do
    get "/fantasy/leaderboard"
    assert_redirected_to combined_leaderboard_path
  end

  test "combined_leaderboard returns 200" do
    get combined_leaderboard_path
    assert_response :success
  end

  # -- Authenticated routes --

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

  test "Devise signup auto-provisions a fantasy portfolio and redirects to overview" do
    season = Season.sorted_by_year.first
    assert_difference -> { User.count } => 1, -> { FantasyPortfolio.count } => 1 do
      post user_registration_path, params: {
        user: {
          email: "autosignup@example.com",
          password: "password123",
          password_confirmation: "password123",
          username: "autosignup",
          terms_accepted: "1"
        }
      }
    end
    user = User.find_by(username: "autosignup")
    assert user.fantasy_portfolio_for(season), "signup should auto-provision a portfolio"
    assert_redirected_to fantasy_overview_path(user.username)
  end

  # -- Toggle public --

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

  # -- Combined leaderboard with stock timing scenarios --

  test "combined leaderboard renders for user with stock portfolio created after first snapshot" do
    get combined_leaderboard_path
    assert_response :success
  end

  test "combined leaderboard renders for single-snapshot late-stock user without 500 error" do
    # Delete latejoin's melbourne snapshot -> single snapshot, stock created after it
    fantasy_snapshots(:latejoin_melbourne).destroy!
    get combined_leaderboard_path
    assert_response :success
  end

  # -- Overview chart start value --

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

  # -- Activity feed --

  test "activity feed shows View all link to dedicated page" do
    sign_in @user
    stock_p = fantasy_stock_portfolios(:codex_stock_2026)
    12.times { |i| stock_p.transactions.create!(kind: "buy", amount: -10 - i) }

    get fantasy_overview_path(@user.username)
    assert_response :success
    assert_select "a[href=?]", fantasy_activity_path(username: @user.username)
  end

  test "activity feed does not render for anonymous viewers" do
    get fantasy_overview_path(@user.username)
    assert_response :success
    assert_select ".fantasy-activity-table", count: 0
  end
end
