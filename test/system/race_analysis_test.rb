require "application_system_test_case"

class RaceAnalysisSystemTest < ApplicationSystemTestCase
  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "reader can explore the debrief and jump to the existing results" do
    visit race_path(races(:bahrain_2026))
    assert_selector "#race-analysis-title", text: "Race debrief"
    assert_text "Elo order vs finish"
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
    assert_selector ".race-analysis-comparison", text: "Verstappen"
    assert_selector ".race-analysis-team", text: "McLaren"
    assert_equal 390, page.evaluate_script("window.innerWidth")
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
    page.save_screenshot(Rails.root.join("tmp/screenshots/race-analysis-mobile.png"))
  end
end
