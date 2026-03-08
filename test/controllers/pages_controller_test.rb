require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home returns 200" do
    get root_path
    assert_response :success
  end

  test "about returns 200" do
    get about_path
    assert_response :success
  end

  test "terms returns 200" do
    get terms_path
    assert_response :success
  end

  test "fantasy_guide returns 200" do
    get fantasy_guide_path
    assert_response :success
  end

  test "elo returns 200" do
    get elo_path
    assert_response :success
  end
end
