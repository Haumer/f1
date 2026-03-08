require "test_helper"

class PredictionsControllerTest < ActionDispatch::IntegrationTest
  test "show returns 200" do
    prediction = predictions(:codex_bahrain_2026)
    get preview_race_path(prediction.race, username: prediction.user.username)
    assert_response :success
  end
end
