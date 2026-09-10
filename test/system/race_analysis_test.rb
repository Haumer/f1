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
    assert_current_path race_path(races(:bahrain_2026)) do |uri|
      uri.fragment == "race-classification"
    end
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
      assert_selector ".race-expectations-leaderboard", count: 2
      assert_selector ".race-expectations-leaders-note", text: "3/4 entrants assessed"
    end
  end

  test "share copies a public deep link without account or query parameters" do
    visit race_path(races(:bahrain_2026), tracking: "private-value")
    wait_for_stimulus("race-analysis-share", ".race-analysis-share")
    find(".race-analysis-share summary").click
    page.execute_script("Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: async (text) => { window.copiedDebrief = text } } })")
    click_button "Copy link"
    assert_selector ".race-analysis-share [role='status']", text: "Link copied."
    assert_equal PublicSite.url(race_path(races(:bahrain_2026), anchor: "race-analysis")), page.evaluate_script("window.copiedDebrief")
    assert_selector "a[href*='/analysis/og.png']", text: "Preview share card"
  end

  test "blocked clipboard leaves a selectable manual link" do
    visit race_path(races(:bahrain_2026))
    wait_for_stimulus("race-analysis-share", ".race-analysis-share")
    find(".race-analysis-share summary").click
    page.execute_script("Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: async () => { throw new Error('Denied') } } })")
    click_button "Copy link"
    assert_selector ".race-analysis-share [role='status']", text: "copy it manually"
    assert_equal "race-analysis-share-url", page.evaluate_script("document.activeElement.id")
    assert_equal find("#race-analysis-share-url").value.length,
                 page.evaluate_script("document.activeElement.selectionEnd - document.activeElement.selectionStart")
  end

  test "native sharing uses the same public link and cancellation does not copy it" do
    visit race_path(races(:bahrain_2026))
    wait_for_stimulus("race-analysis-share", ".race-analysis-share")
    find(".race-analysis-share summary").click
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'share', { configurable: true, value: async (data) => { window.sharedDebrief = data; throw new DOMException('Cancelled', 'AbortError') } });
      Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: async () => { window.unwantedCopy = true } } });
      window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('.race-analysis-share'), 'race-analysis-share').connect();
    JS
    click_button "Share…"
    assert_equal PublicSite.url(race_path(races(:bahrain_2026), anchor: "race-analysis")), page.evaluate_script("window.sharedDebrief.url")
    assert_nil page.evaluate_script("window.unwantedCopy")
    assert_no_text "Link copied."
  end
end
