require "test_helper"

class DriversControllerTest < ActionDispatch::IntegrationTest
  test "index returns 200" do
    get drivers_path
    assert_response :success
  end

  test "show returns 200" do
    get driver_path(drivers(:verstappen))
    assert_response :success
  end

  test "grid returns 200" do
    get grid_drivers_path
    assert_response :success
  end

  test "peak_elo returns 200" do
    get peak_elo_drivers_path
    assert_response :success
  end

  test "current_active_elo returns 200" do
    get current_active_elo_drivers_path
    assert_response :success
  end

  test "compare returns 200" do
    get compare_drivers_path
    assert_response :success
  end

  test "compare with specific drivers returns 200" do
    ids = [drivers(:verstappen).id, drivers(:norris).id].join(",")
    get compare_drivers_path(driver_ids: ids)
    assert_response :success
  end

  test "by_nationality returns 200" do
    get by_nationality_drivers_path
    assert_response :success
  end

  test "search returns JSON" do
    get search_drivers_path(q: "Ver", format: :json)
    assert_response :success
  end

  test "search with short query returns empty array" do
    get search_drivers_path(q: "V", format: :json)
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end
end
