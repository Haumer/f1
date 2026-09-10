require "test_helper"
require "minitest/mock"

class RaceAnalysisImagesControllerTest < ActionDispatch::IntegrationTest
  test "public image is cached and conditional requests skip generation" do
    race = races(:bahrain_2026)
    generator = Minitest::Mock.new
    generator.expect(:generate, "PNG bytes")
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      RaceAnalysisOgGenerator.stub(:new, generator) do
        get analysis_og_image_race_path(race)
        assert_response :success
        assert_equal "image/png", response.media_type
        assert_equal "PNG bytes", response.body
        assert_includes response.headers["Cache-Control"], "public"
        assert_includes response.headers["Cache-Control"], "max-age=300"
        etag = response.headers["ETag"]
        get analysis_og_image_race_path(race), headers: { "If-None-Match" => etag }
        assert_response :not_modified
        get analysis_og_image_race_path(race, v: "arbitrary-input")
        assert_response :success
        assert_equal "PNG bytes", response.body
      end
    end
    generator.verify
  end

  test "races without results and missing races have no debrief image" do
    get analysis_og_image_race_path(races(:melbourne_2026))
    assert_response :not_found
    get analysis_og_image_race_path(id: 0)
    assert_response :not_found
  end
end
