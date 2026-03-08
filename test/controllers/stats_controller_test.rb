require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  test "index returns 200" do
    get stats_path
    assert_response :success
  end

  test "elo_milestones returns 200" do
    get elo_milestones_path
    assert_response :success
  end

  test "fan_standings returns 200" do
    get fan_standings_path
    assert_response :success
  end

  test "badges returns 200" do
    get badges_path
    assert_response :success
  end
end
