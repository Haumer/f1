require "test_helper"
require_relative "../support/race_expectation_history"

class RaceDebriefsControllerTest < ActionDispatch::IntegrationTest
  include RaceExpectationHistory

  test "public debrief renders first without tabs and has its own canonical share URL" do
    race = races(:bahrain_2026)
    url = PublicSite.url(debrief_race_path(race))
    RaceExpectations::Dataset.stub(:before, expectation_history) do
      get debrief_race_path(race), params: { tab: "qualifying", tracking: "not-shared" }
    end

    assert_response :success
    assert_select ".race-debrief-identity h1", race.circuit.name
    assert_select ".race-debrief-page > #race-analysis", count: 1
    assert_select ".race-expectations-leaderboard", count: 2
    assert_select ".race-expectations-table tbody tr", count: 4
    assert_select "[data-controller='tab-table'], #race-classification", count: 0
    assert_select "link[rel='canonical'][href='#{url}']", count: 1
    assert_select "meta[property='og:url'][content='#{url}']", count: 1
    assert_select "meta[property='og:title'][content*='#{race.circuit.name}']", count: 1
    assert_select "meta[property='og:image'][content^='#{PublicSite.url(analysis_og_image_race_path(race))}?v=']", count: 1
    assert_select "input#race-analysis-share-url[value='#{url}']", count: 1
    assert_select "a[href='#{race_path(race, anchor: 'race-classification')}']", text: "Results & qualifying →"
  end

  test "a race without results never falls back to another race's debrief" do
    race = races(:melbourne_2026)
    get debrief_race_path(race)

    assert_response :success
    assert_select ".race-debrief-identity h1", race.circuit.name
    assert_select "#race-debrief-pending-title", "Debrief not available yet"
    assert_select "#race-analysis, .race-expectations-table, .race-expectations-leaderboard", count: 0
    assert_select "meta[property='og:image'][content*='/analysis/og.png']", count: 0
    assert_select "a[href='#{race_path(race)}']", text: /this race's schedule/
  end

  test "missing estimates do not hide a race's stored field" do
    race = races(:bahrain_2026)
    get debrief_race_path(race)

    assert_response :success
    assert_select ".race-expectations > .race-expectations-notice", text: /0\/4 entrants have an estimate/
    assert_select ".race-expectations-table tbody tr", count: 4
  end

  test "unknown races return not found instead of selecting the latest race" do
    get debrief_race_path(id: 0)
    assert_response :not_found
  end
end
