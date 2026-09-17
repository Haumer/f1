require "application_system_test_case"

class RaceDetailsTest < ApplicationSystemTestCase
  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "phone rows reveal details keep driver links and sort with their detail row" do
    [320, 390].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: true)
      visit race_path(races(:bahrain_2026))
      wait_for_stimulus "result-details", "#race-classification-race-panel table"
      button = find("button[aria-label='Details for Max Verstappen']")
      detail_id = button["aria-controls"]
      button.click
      assert_selector "##{detail_id}", text: "Grid"
      assert_selector "##{detail_id}", text: "Points"
      assert_selector "##{detail_id}", text: "Finished"
      assert_podium_colors
      find("#race-classification-race-panel th[data-sort='text']").click
      assert_equal detail_id, page.evaluate_script("document.querySelector('button[aria-controls=\"#{detail_id}\"]').closest('tr').nextElementSibling.id")
      assert_link "M.Verstappen", href: driver_path(drivers(:verstappen))
      click_button "Qualifying"
      find("button[aria-label='Details for Max Verstappen']").click
      assert_selector ".result-details-row", text: "Q1"
      assert_selector ".result-details-row", text: "Q3"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width
    end
  end

  test "desktop retains compact rows and its full classification" do
    visit race_path(races(:bahrain_2026))
    wait_for_stimulus "result-details", "#race-classification-race-panel table"
    assert_no_selector ".result-detail-toggle"
    assert_no_selector ".result-details-row"
    assert_selector "#race-classification-race-panel th", text: "GRID"
    assert_selector "#race-classification-race-panel .result-position-label", text: "P1"
    assert_podium_colors
  end

  private

  def assert_podium_colors
    colors = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('#race-classification-race-panel tbody tr:not(.result-details-row)')).slice(0, 3).map(row => getComputedStyle(row.cells[0]).color)
    JS
    assert_equal ["rgb(240, 200, 80)", "rgb(160, 160, 176)", "rgb(212, 132, 74)"], colors
  end
end
