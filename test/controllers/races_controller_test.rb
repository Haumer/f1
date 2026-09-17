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
    assert_select ".race-section-nav", count: 0
    assert_select "button.table-tab.active[data-tab='race']", text: "Race"
    assert_select "button[data-tab='debrief']", text: "Debrief"
    assert_select "button[data-tab='elo']", text: "Elo"
    assert_select "[data-tab-table-target='panel'][data-tab='debrief'][style='display:none']"
    assert_select "#race-analysis-method", text: /not isolate driver skill/
    assert_operator response.body.index('id="race-classification"'), :<, response.body.index('id="race-analysis"')
  end

  test "debrief and Elo tabs can be linked directly and only show after results" do
    %w[debrief elo].each do |tab|
      get race_path(races(:bahrain_2026), tab: tab)
      assert_response :success
      assert_select "button.table-tab.active[data-tab='#{tab}']"
      assert_select "[data-tab-table-target='panel'][data-tab='#{tab}'][style='']"
      assert_select "[data-tab-table-target='panel'][data-tab='race'][style='display:none']"

      get race_path(races(:melbourne_2026), tab: tab)
      assert_response :success
      assert_select "button[data-tab='#{tab}']", count: 0
      assert_select "button.table-tab.active[data-tab='race']"
    end
  end

  test "normal race and shared debrief retain the global champion accent instead of the race winner" do
    championship = driver_standings(:melbourne_2025_verstappen)
    RaceResult.create!(race: championship.race, driver: championship.driver, constructor: constructors(:ferrari),
                       status: statuses(:finished), position: 1, position_order: 1, points: 25)
    Rails.cache.delete('current_champion_accent')
    [race_path(races(:bahrain_2026)), debrief_race_path(races(:bahrain_2026))].each do |url|
      get url
      assert_select "body[style*='--page-accent: #{Constructor::COLORS[:ferrari]}']", count: 1
    end
  ensure
    Rails.cache.delete('current_champion_accent')
  end

  test "classification uses the event constructor when the season roster disagrees" do
    race = races(:bahrain_2026)
    race.update!(sprint_time: '13:00:00Z')
    result = race.race_results.find_by!(driver: drivers(:verstappen))
    result.update!(constructor: constructors(:ferrari))
    sprint = result.dup
    sprint.result_type = 'sprint'
    sprint.save!
    get race_path(race)

    %w[race sprint].each do |panel|
      assert_select "[data-tab-table-target='panel'][data-tab='#{panel}'] tbody tr:first-child" do
        assert_select "td.col-logo a[href='#{constructor_path(constructors(:ferrari))}']", count: 1
        assert_select "td.col-logo a[href='#{constructor_path(constructors(:red_bull))}']", count: 0
      end
    end
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
    assert_select ".session-data-status", text: "Qualifying results are unavailable for this race in our data."
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
    assert_select "details#race-expectations-info:not([open]) .race-expectations-context", text: /No results from this race/
    assert_select "details.race-expectations-ranking-info:not([open])", text: /not poor driving/
    assert_select ".race-expectations-heading p", count: 0
    assert_select ".race-expectations-leaderboard[aria-label='Top 3'] li", minimum: 1
    assert_select ".race-expectations-leaderboard[aria-label='Flop 3'] li", minimum: 1
    assert_select ".race-expectations-leaders-note", text: /3\/4 entrants assessed/
    assert_select ".race-expectations-leaderboard", text: /Piastri/, count: 0
    assert_select "meta[property='og:title'][content*='Race debrief']"
    assert_select "meta[property='og:image'][content^='#{PublicSite.url(analysis_og_image_race_path(races(:bahrain_2026)))}?v=']"
    assert_select "meta[property='og:image:alt'][content*='Top 3 and Flop 3']"
    assert_select "input#race-analysis-share-url[value='#{PublicSite.url(debrief_race_path(races(:bahrain_2026)))}']"
  end

  test "missing history stays visible outside collapsed model notes" do
    get race_path(races(:bahrain_2026))
    assert_select ".race-expectations > .race-expectations-notice", text: /0\/4 entrants have an estimate.*Not enough earlier history/m
    assert_select ".race-expectations-leaders-note", text: /DNFs excluded/
    assert_select "details#race-expectations-info:not([open])", count: 1
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
