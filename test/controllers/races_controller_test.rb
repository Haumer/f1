require "test_helper"

class RacesControllerTest < ActionDispatch::IntegrationTest
  test "index returns 200" do
    get races_path
    assert_response :success
  end

  test "show returns 200 for race with results" do
    get race_path(races(:bahrain_2026))
    assert_response :success
  end

  test "show returns 200 for race without results" do
    get race_path(races(:melbourne_2026))
    assert_response :success
  end

  test "calendar returns 200" do
    get calendar_races_path
    assert_response :success
  end

  test "highest_elo returns 200" do
    get highest_elo_races_path
    assert_response :success
  end

  test "podiums returns 200" do
    get podiums_races_path
    assert_response :success
  end

  test "winners returns 200" do
    get winners_races_path
    assert_response :success
  end
end
