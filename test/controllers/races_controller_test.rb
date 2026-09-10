require "test_helper"
require_relative "../support/race_expectation_history"

class RacesControllerTest < ActionDispatch::IntegrationTest
  include RaceExpectationHistory
  test "index returns 200" do
    get races_path
    assert_response :success
  end

  test "show returns 200 for race with results" do
    get race_path(races(:bahrain_2026))
    assert_response :success
    assert_select "#race-analysis h2", "Race debrief"
    assert_select ".race-analysis-highlight", count: 3
    assert_select ".race-expectations-table tbody tr", count: 4
    assert_select ".race-expectations-heading", text: /Did they beat the expectation/
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
    assert_select ".race-expectations-table tbody tr", count: 4
    assert_select ".race-expectations-table", text: /Pre-race Elo unavailable/
    assert_select ".race-analysis-highlight", count: 1
    assert_select "p", text: "Qualifying results are not available for this race."
  end

  test "full grid estimates render both qualifying and model provenance" do
    RaceExpectations::Dataset.stub(:before, expectation_history) do
      get race_path(races(:bahrain_2026))
    end
    assert_response :success
    assert_select ".race-expectations-table tbody tr[data-expected]:not([data-expected=''])", count: 4
    assert_select ".race-expectations-errors", text: /Elo \+ qualifying/
    assert_select ".race-expectations-reading", text: /DNF/
    assert_select ".race-expectations-context", text: /45 races/
    assert_select ".race-expectations-leaderboard[aria-label='Top 3'] li", minimum: 1
    assert_select ".race-expectations-leaderboard[aria-label='Flop 3'] li", minimum: 1
    assert_select ".race-expectations-leaders-note", text: /3\/4 entrants assessed/
    assert_select ".race-expectations-leaderboard", text: /Piastri/, count: 0
    assert_select "meta[property='og:title'][content*='Race debrief']"
    assert_select "meta[property='og:image'][content^='#{PublicSite.url(analysis_og_image_race_path(races(:bahrain_2026)))}?v=']"
    assert_select "meta[property='og:image:alt'][content*='Top 3 and Flop 3']"
    assert_select "input#race-analysis-share-url[value='#{PublicSite.url(race_path(races(:bahrain_2026), anchor: 'race-analysis'))}']"
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
