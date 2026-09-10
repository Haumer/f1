require "test_helper"

class RacesControllerTest < ActionDispatch::IntegrationTest
  test "index returns 200" do
    get races_path
    assert_response :success
  end

  test "show returns 200 for race with results" do
    get race_path(races(:bahrain_2026))
    assert_response :success
    assert_select "#race-analysis h2", "Race debrief"
    assert_select ".race-analysis-highlight", count: 3
    assert_select ".race-analysis-comparison tbody tr", count: 3
    assert_select "a[href='#race-classification']", "Results & qualifying"
    assert_select "#race-analysis-method", text: /not isolate driver skill/
  end

  test "show returns 200 for race without results" do
    get race_path(races(:melbourne_2026))
    assert_response :success
    assert_select "#race-analysis", count: 0
  end

  test "race debrief handles missing Elo and qualifying data" do
    race = races(:bahrain_2026)
    race.race_results.update_all(old_elo_v2: nil, new_elo_v2: nil)
    race.qualifying_results.destroy_all
    get race_path(race)

    assert_response :success
    assert_select ".race-analysis-coverage", text: %r{0/4.*Elo snapshots.*0/4.*qualifying}m
    assert_select ".race-analysis-comparison", count: 0
    assert_select ".race-analysis-empty", text: /Missing ratings are not treated as zero/
    assert_select ".race-analysis-highlight", count: 1
    assert_select "p", text: "Qualifying results are not available for this race."
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
