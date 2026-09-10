require "application_system_test_case"
require_relative "../support/race_expectation_history"

class RaceAnalysisSystemTest < ApplicationSystemTestCase
  include RaceExpectationHistory

  setup do
    # Supply enough synthetic earlier races to exercise predictions in the UI.
    @history = expectation_history
  end
  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "reader can explore the debrief and jump to the existing results" do
    visit race_path(races(:bahrain_2026))
    assert_selector "#race-analysis-title", text: "Race debrief"
    assert_text "Did they beat the expectation?"
    find("#race-analysis-method summary").click
    assert_text "Equal ratings share the midpoint"
    find("#race-analysis-title").scroll_to(:top)
    page.save_screenshot(Rails.root.join("tmp/screenshots/race-analysis-desktop.png"))
    click_link "Results & qualifying"
    assert_selector "#race-classification table"
    assert_equal "race-classification", URI.parse(current_url).fragment
  end

  test "debrief fits a phone and keeps exact comparison values readable" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit race_path(races(:bahrain_2026), anchor: "race-analysis")
    assert_selector ".race-expectations-table", text: "Verstappen"
    assert_selector ".race-analysis-team", text: "McLaren"
    assert_equal 390, page.evaluate_script("window.innerWidth")
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
    page.save_screenshot(Rails.root.join("tmp/screenshots/race-analysis-mobile.png"))
  end

  test "entire field can be ordered by expectation with unassessed entries last" do
    RaceExpectations::Dataset.stub(:before, @history) do
      visit race_path(races(:bahrain_2026), anchor: "race-analysis")
      wait_for_stimulus("race-expectations", ".race-expectations")
      assert_selector ".race-expectations-table tbody tr", count: 4
      select "Above expectation", from: "race-expectations-sort"
      rows = all(".race-expectations-table tbody tr")
      assert_includes rows.last.text, "Piastri"
      assert_includes rows.last.text, "Not assessed"
      differences = rows.first(3).map { |row| row["data-difference"].to_f }
      assert_equal differences.sort.reverse, differences
      find(".race-expectations-validation summary").click
      assert_text "Elo + qualifying"
    end
  end

  test "phone cards show Elo qualifying expected and actual positions" do
    RaceExpectations::Dataset.stub(:before, @history) do
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
      visit race_path(races(:bahrain_2026), anchor: "race-analysis")
      assert_selector ".race-expectations-table td[data-label='Expected'] strong", text: /P\d/
      assert_selector ".race-expectations-table td[data-label='Qualifying']", text: "P1"
      assert_equal 390, page.evaluate_script("window.innerWidth")
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 390
    end
  end
end
