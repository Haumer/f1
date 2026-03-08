require "test_helper"

class SeasonsControllerTest < ActionDispatch::IntegrationTest
  test "index returns 200" do
    get seasons_path
    assert_response :success
  end

  test "show returns 200 for season with standings" do
    get season_path(seasons(:season_2026))
    assert_response :success
  end

  test "show returns 200 for season without standings" do
    get season_path(seasons(:season_2025))
    assert_response :success
  end
end
