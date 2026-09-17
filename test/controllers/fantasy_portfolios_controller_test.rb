require "test_helper"

class FantasyPortfoliosControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:codex)
    @portfolio = fantasy_portfolios(:codex_2026)
  end

  # -- Public routes --

  test "weekend chip says saved while editable and locked only after race start" do
    race = races(:melbourne_2026)
    race.update!(date: Date.current + 5.days, time: "14:00:00")
    RacePick.create!(user: @user, race: race, locked_at: race.starts_at,
                     picks: [{ driver_id: drivers(:norris).id, position: 1, source: "manual" }])
    sign_in @user
    get fantasy_overview_path(@user.username)
    assert_select ".fantasy-weekend-chip-sub", text: "Saved · editable"
    race.update!(date: Date.yesterday)
    get fantasy_overview_path(@user.username)
    assert_select ".fantasy-weekend-chip-sub", text: "Locked"
    assert_select ".fantasy-weekend-chip-sub", text: "Saved · editable", count: 0
  end

  test "overview returns 200 for logged-in owner" do
    sign_in @user
    get fantasy_overview_path(@user.username)
    assert_response :success
  end

  test "overview returns 200 for logged-out visitor" do
    @user.update_columns(public_profile: true)
    get fantasy_overview_path(@user.username)
    assert_response :success
    assert_select ".fantasy-public-challenge"
    assert_select "a[href=?]", new_user_registration_path, text: "Play free"
  end

  test "owner overview does not render the public challenge" do
    sign_in @user
    get fantasy_overview_path(@user.username)

    assert_response :success
    assert_select ".fantasy-public-challenge", count: 0
    assert_select ".fantasy-header-actions a[href=?]", market_fantasy_stock_portfolio_path(fantasy_stock_portfolios(:codex_stock_2026)), text: /Market/
    assert_select "form[action=?]", toggle_public_profile_path, count: 1
    assert_select ".fantasy-header-actions a", text: "My portfolio", count: 0
  end

  test "signed-in member viewing another portfolio sees a compact return link without the public pitch" do
    @user.update!(public_profile: true)
    viewer = users(:latejoin)
    sign_in viewer

    get fantasy_overview_path(@user.username)

    assert_response :success
    assert_select ".fantasy-dashboard-name", text: @user.display_name
    assert_select ".fantasy-public-challenge", count: 0
    assert_select ".fantasy-dashboard-meta", text: /Public portfolio/
    assert_select ".fantasy-header-actions a[href=?]", fantasy_overview_path(viewer.username), text: "My portfolio"
    assert_select ".fantasy-header-actions a[href=?]", market_fantasy_stock_portfolio_path(fantasy_stock_portfolios(:codex_stock_2026)), count: 0
    assert_select "form[action=?]", toggle_public_profile_path, count: 0
    assert_select ".fantasy-pitwall-weekend", count: 0
    assert_select ".fantasy-activity-table", count: 0
  end

  test "signed-in visitor without a portfolio can start their season from the header" do
    @user.update!(public_profile: true)
    viewer = User.create!(email: "viewer@example.com", password: "password123", username: "viewer", terms_accepted: "1")
    sign_in viewer

    get fantasy_overview_path(@user.username)

    assert_response :success
    assert_select ".fantasy-public-challenge", count: 0
    assert_select ".fantasy-header-actions a[href=?]", new_fantasy_portfolio_path, text: "Start my season"
    assert_select "a[href=?]", new_user_registration_path, count: 0
    assert_select "form[action=?]", toggle_public_profile_path, count: 0
  end

  test "being signed in does not grant access to someone else's private portfolio" do
    @user.update!(public_profile: false)
    sign_in users(:latejoin)

    get fantasy_overview_path(@user.username)

    assert_redirected_to combined_leaderboard_path
    assert_equal "This profile is private.", flash[:alert]
  end

  test "private portfolio owner keeps their dashboard controls" do
    @user.update!(public_profile: false)
    sign_in @user

    get fantasy_overview_path(@user.username)

    assert_response :success
    assert_select ".fantasy-public-challenge", count: 0
    assert_select ".fantasy-header-actions a[href=?]", market_fantasy_stock_portfolio_path(fantasy_stock_portfolios(:codex_stock_2026)), text: /Market/
    assert_select "form[action=?]", toggle_public_profile_path, count: 1
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
