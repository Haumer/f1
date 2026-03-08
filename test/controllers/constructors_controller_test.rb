require "test_helper"

class ConstructorsControllerTest < ActionDispatch::IntegrationTest
  test "index returns 200" do
    get constructors_path
    assert_response :success
  end

  test "show returns 200" do
    get constructor_path(constructors(:mclaren))
    assert_response :success
  end

  test "grid returns 200" do
    get grid_constructors_path
    assert_response :success
  end

  test "elo_rankings returns 200" do
    get elo_rankings_constructors_path
    assert_response :success
  end

  test "best_pairings returns 200" do
    get best_pairings_constructors_path
    assert_response :success
  end

  test "families returns 200" do
    get families_constructors_path
    assert_response :success
  end

  test "support requires authentication" do
    post support_constructor_path(constructors(:mclaren))
    assert_response :redirect
  end
end
