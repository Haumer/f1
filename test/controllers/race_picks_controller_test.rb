require "test_helper"

class RacePicksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:codex)
    @race = races(:melbourne_2026) # next race after bahrain_2026 which has results
    # Treat it as a genuinely upcoming race so picks are open (the edit form is
    # only shown while picks_open?). Lock-specific tests set locked_at on the
    # pick itself, independent of this.
    @race.update!(date: Date.current + 5.days, time: "14:00:00")
  end

  # ═══════ Authentication ═══════

  test "edit renders for guests" do
    get edit_race_picks_path
    assert_response :success
  end

  test "update redirects when not signed in" do
    patch race_picks_path, params: { picks: "[]" }
    assert_response :redirect
  end

  test "stash saves picks to session and redirects to signup" do
    picks_data = [
      { driver_id: drivers(:verstappen).id, position: 1, source: "manual" }
    ].to_json

    post stash_race_picks_path, params: { picks: picks_data }
    assert_redirected_to new_user_registration_path
    assert_match /account/, flash[:notice]
  end

  # ═══════ Edit ═══════

  test "edit renders successfully" do
    sign_in @user
    get edit_race_picks_path
    assert_response :success
  end

  test "edit redirects signed-in user once picks are locked" do
    sign_in @user
    @race.update!(date: Date.current - 1.day, time: "14:00:00") # race already started
    get edit_race_picks_path
    assert_redirected_to fantasy_overview_path(@user.username)
    assert_match(/locked/i, flash[:notice])
  end

  test "edit shows driver cards" do
    sign_in @user
    get edit_race_picks_path
    assert_response :success

    # Should show the current season drivers
    assert_select "[data-driver-id]", minimum: 1
  end

  test "edit loads existing picks" do
    sign_in @user
    picks_data = [
      { "driver_id" => drivers(:verstappen).id, "position" => 1, "source" => "manual" },
      { "driver_id" => drivers(:norris).id, "position" => 2, "source" => "manual" }
    ]
    RacePick.create!(user: @user, race: @race, picks: picks_data)

    get edit_race_picks_path
    assert_response :success
  end

  # ═══════ Update ═══════

  test "update creates a new race pick" do
    sign_in @user
    picks_data = [
      { driver_id: drivers(:verstappen).id, position: 1, source: "manual" },
      { driver_id: drivers(:norris).id, position: 2, source: "manual" }
    ].to_json

    assert_difference "RacePick.count", 1 do
      patch race_picks_path, params: { picks: picks_data }
    end

    assert_redirected_to race_pick_compare_path(username: @user.username, race_id: @race.id)
    pick = RacePick.find_by(user: @user, race: @race)
    assert_equal 2, pick.picks.size
    assert_equal drivers(:verstappen).id, pick.picks.first["driver_id"]
  end

  test "update saves picks with correct structure" do
    sign_in @user
    picks_data = [
      { driver_id: drivers(:verstappen).id, position: 1, source: "manual" },
      { driver_id: drivers(:norris).id, position: 2, source: "random" }
    ].to_json

    patch race_picks_path, params: { picks: picks_data }

    pick = RacePick.find_by(user: @user, race: @race)
    manual = pick.manual_picks
    assert_equal 1, manual.size
    assert_equal "manual", pick.picks.first["source"]
    assert_equal "random", pick.picks.second["source"]
  end

  test "update sets locked_at to race start time" do
    sign_in @user
    picks_data = [
      { driver_id: drivers(:verstappen).id, position: 1, source: "manual" }
    ].to_json

    patch race_picks_path, params: { picks: picks_data }

    pick = RacePick.find_by(user: @user, race: @race)
    assert_equal @race.starts_at, pick.locked_at
  end

  test "update overwrites existing picks" do
    sign_in @user
    RacePick.create!(user: @user, race: @race, picks: [
      { "driver_id" => drivers(:verstappen).id, "position" => 1, "source" => "manual" }
    ])

    new_picks = [
      { driver_id: drivers(:norris).id, position: 1, source: "manual" },
      { driver_id: drivers(:leclerc).id, position: 2, source: "manual" },
      { driver_id: drivers(:verstappen).id, position: 3, source: "manual" }
    ].to_json

    assert_no_difference "RacePick.count" do
      patch race_picks_path, params: { picks: new_picks }
    end

    pick = RacePick.find_by(user: @user, race: @race)
    assert_equal 3, pick.picks.size
    assert_equal drivers(:norris).id, pick.picks.first["driver_id"]
  end

  test "update rejects locked picks" do
    sign_in @user
    RacePick.create!(user: @user, race: @race, picks: [
      { "driver_id" => drivers(:verstappen).id, "position" => 1, "source" => "manual" }
    ], locked_at: 1.hour.ago)

    patch race_picks_path, params: { picks: [].to_json }
    assert_redirected_to fantasy_overview_path(@user.username)
    assert_match /locked/i, flash[:alert]
  end

  test "update handles empty picks" do
    sign_in @user
    patch race_picks_path, params: { picks: "[]" }
    assert_redirected_to race_pick_compare_path(username: @user.username, race_id: @race.id)

    pick = RacePick.find_by(user: @user, race: @race)
    assert_equal [], pick.picks
  end

  # ═══════ Edit — driver data ═══════

  test "edit shows all season drivers sorted by form" do
    sign_in @user
    get edit_race_picks_path
    assert_response :success

    # All 4 fixture drivers should appear
    assert_select "[data-driver-id]", count: 4
  end

  test "edit shows driver elo on cards" do
    sign_in @user
    get edit_race_picks_path

    assert_select "[data-driver-elo]", minimum: 1
  end

  test "edit shows driver team on cards" do
    sign_in @user
    get edit_race_picks_path

    assert_select "[data-driver-team]", minimum: 1
  end

  test "edit shows last result position on cards" do
    sign_in @user
    get edit_race_picks_path

    assert_select "[data-driver-last-pos]", minimum: 1
  end

  test "edit pre-fills hidden input with existing picks" do
    sign_in @user
    picks_data = [
      { "driver_id" => drivers(:verstappen).id, "position" => 1, "source" => "manual" }
    ]
    RacePick.create!(user: @user, race: @race, picks: picks_data)

    get edit_race_picks_path
    assert_select "input[name='picks']" do |inputs|
      value = JSON.parse(inputs.first["value"])
      assert_equal 1, value.size
      assert_equal drivers(:verstappen).id, value.first["driver_id"]
    end
  end

  # ═══════ Update — edge cases ═══════

  test "update with full grid of all drivers" do
    sign_in @user
    all_drivers = [drivers(:verstappen), drivers(:norris), drivers(:leclerc), drivers(:piastri)]
    picks_data = all_drivers.each_with_index.map do |d, i|
      { driver_id: d.id, position: i + 1, source: i < 2 ? "manual" : "random" }
    end.to_json

    patch race_picks_path, params: { picks: picks_data }
    assert_redirected_to race_pick_compare_path(username: @user.username, race_id: @race.id)

    pick = RacePick.find_by(user: @user, race: @race)
    assert_equal 4, pick.picks.size
    assert_equal 2, pick.manual_picks.size
  end

  test "update preserves source field for each pick" do
    sign_in @user
    picks_data = [
      { driver_id: drivers(:verstappen).id, position: 1, source: "manual" },
      { driver_id: drivers(:norris).id, position: 2, source: "random" },
      { driver_id: drivers(:leclerc).id, position: 3, source: "manual" },
      { driver_id: drivers(:piastri).id, position: 4, source: "random" }
    ].to_json

    patch race_picks_path, params: { picks: picks_data }

    pick = RacePick.find_by(user: @user, race: @race)
    sources = pick.picks.map { |p| p["source"] }
    assert_equal ["manual", "random", "manual", "random"], sources
  end

  test "update with missing picks param saves empty array" do
    sign_in @user
    patch race_picks_path, params: { picks: "" }
    assert_redirected_to race_pick_compare_path(username: @user.username, race_id: @race.id)

    pick = RacePick.find_by(user: @user, race: @race)
    assert_equal [], pick.picks
  end

  test "update does not modify locked pick data" do
    sign_in @user
    original_picks = [
      { "driver_id" => drivers(:verstappen).id, "position" => 1, "source" => "manual" }
    ]
    RacePick.create!(user: @user, race: @race, picks: original_picks, locked_at: 1.hour.ago)

    new_picks = [
      { driver_id: drivers(:norris).id, position: 1, source: "manual" }
    ].to_json

    patch race_picks_path, params: { picks: new_picks }

    pick = RacePick.find_by(user: @user, race: @race)
    assert_equal drivers(:verstappen).id, pick.picks.first["driver_id"]
  end

  test "update flash message includes circuit name" do
    sign_in @user
    picks_data = [
      { driver_id: drivers(:verstappen).id, position: 1, source: "manual" }
    ].to_json

    patch race_picks_path, params: { picks: picks_data }
    assert_match @race.circuit.name, flash[:notice]
  end

  # ═══════ Results (scorecard) ═══════

  # bahrain_2026 fixtures: VER P1, NOR P2, LEC P3, PIA P4.
  def scored_pick_for(user)
    RacePick.create!(user: user, race: races(:bahrain_2026), picks: [
      { "driver_id" => drivers(:verstappen).id, "position" => 1, "source" => "manual" }, # exact
      { "driver_id" => drivers(:norris).id,     "position" => 3, "source" => "manual" }, # off by 1
      { "driver_id" => drivers(:leclerc).id,    "position" => 3, "source" => "manual" }, # exact
    ])
  end

  test "results renders the scorecard for the owner" do
    sign_in @user
    scored_pick_for(@user)

    get race_pick_results_path(@user.username, races(:bahrain_2026).id)
    assert_response :success
    # 50 (VER exact) + 30 (NOR off-by-1) + 50 (LEC exact) = 130
    assert_select ".scorecard-summary-value", text: "130"
    assert_select ".scorecard-row", count: 3
  end

  test "results is visible to visitors when the profile is public" do
    @user.update_columns(public_profile: true)
    scored_pick_for(@user)

    get race_pick_results_path(@user.username, races(:bahrain_2026).id)
    assert_response :success
  end

  test "results is hidden from visitors when the profile is private" do
    @user.update_columns(public_profile: false)
    scored_pick_for(@user)

    get race_pick_results_path(@user.username, races(:bahrain_2026).id)
    assert_redirected_to combined_leaderboard_path
  end

  test "results redirects when the user has no pick for that race" do
    sign_in @user
    get race_pick_results_path(@user.username, races(:bahrain_2026).id)
    assert_redirected_to fantasy_overview_path(@user.username)
  end

  test "results redirects when the race has no results yet" do
    sign_in @user
    RacePick.create!(user: @user, race: @race, picks: [
      { "driver_id" => drivers(:verstappen).id, "position" => 1, "source" => "manual" }
    ])
    get race_pick_results_path(@user.username, @race.id) # melbourne_2026 has no results
    assert_redirected_to fantasy_overview_path(@user.username)
  end
end
