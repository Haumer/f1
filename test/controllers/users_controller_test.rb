require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:codex)
  end

  # ── username_available ──

  test "username_available returns json" do
    get users_username_available_path(username: "available_name")
    assert_response :success
    body = JSON.parse(response.body)
    assert body.key?("available")
  end

  test "username_available returns false for short names" do
    get users_username_available_path(username: "ab")
    body = JSON.parse(response.body)
    refute body["available"]
  end

  test "username_available returns false for taken username" do
    get users_username_available_path(username: @user.username)
    body = JSON.parse(response.body)
    refute body["available"]
  end

  # ── show ──

  test "show requires authentication" do
    get user_settings_path(@user.username)
    assert_response :redirect
  end

  test "show returns 200 for own profile" do
    sign_in @user
    get user_settings_path(@user.username)
    assert_response :success
  end

  test "show redirects for other users profile" do
    other = User.create!(email: "other@example.com", password: "password123", username: "otheruser", terms_accepted: "1")
    sign_in other
    get user_settings_path(@user.username)
    assert_redirected_to root_path
  end

  # ── update ──

  test "update requires authentication" do
    patch user_settings_path(@user.username), params: { user: { username: "newname" } }
    assert_response :redirect
  end

  test "update changes username" do
    sign_in @user
    patch user_settings_path(@user.username), params: { user: { username: "newcodex" } }
    assert_equal "newcodex", @user.reload.username
  end

  test "update rejects other users profile" do
    other = User.create!(email: "other2@example.com", password: "password123", username: "otherusr2", terms_accepted: "1")
    sign_in other
    patch user_settings_path(@user.username), params: { user: { username: "hacked" } }
    assert_redirected_to root_path
    refute_equal "hacked", @user.reload.username
  end
end
