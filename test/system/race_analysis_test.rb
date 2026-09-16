require "application_system_test_case"
require_relative "../support/race_expectation_history"

class RaceAnalysisSystemTest < ApplicationSystemTestCase
  include RaceExpectationHistory

  setup do
    FileUtils.mkdir_p(Rails.root.join("tmp/screenshots/mobile-polish"))
    # Supply enough synthetic earlier races to exercise predictions in the UI.
    @history = expectation_history
  end
  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "reader can explore the debrief and jump to the existing results" do
    visit race_path(races(:bahrain_2026))
    assert_no_selector "#race-analysis-title"
    wait_for_stimulus "tab-table", "#race-classification"
    click_button "Debrief"
    assert_selector "#race-analysis-title", text: "Race debrief"
    assert_text "Did they beat the expectation?"
    find("#race-analysis-method summary").click
    assert_text "Equal ratings share the midpoint"
    find("#race-analysis-title").scroll_to(:top)
    page.save_screenshot(Rails.root.join("tmp/screenshots/race-analysis-desktop.png"))
    click_button "Race", exact: true
    assert_selector "#race-classification table"
    assert_selector "button[aria-selected='true']", text: "Race", exact_text: true
    assert_no_selector "#race-analysis-title"
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
    visit race_path(races(:bahrain_2026), tracking: "private-value", tab: "debrief")
    wait_for_stimulus("race-analysis-share", ".race-analysis-share")
    find(".race-analysis-share summary").click
    page.execute_script("Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: async (text) => { window.copiedDebrief = text } } })")
    click_button "Copy link"
    assert_selector ".race-analysis-share [role='status']", text: "Link copied."
    assert_equal PublicSite.url(debrief_race_path(races(:bahrain_2026))), page.evaluate_script("window.copiedDebrief")
    assert_selector "a[href*='/analysis/og.png']", text: "Preview share card"
  end

  test "blocked clipboard leaves a selectable manual link" do
    visit race_path(races(:bahrain_2026), tab: "debrief")
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
    visit race_path(races(:bahrain_2026), tab: "debrief")
    wait_for_stimulus("race-analysis-share", ".race-analysis-share")
    find(".race-analysis-share summary").click
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'share', { configurable: true, value: async (data) => { window.sharedDebrief = data; throw new DOMException('Cancelled', 'AbortError') } });
      Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: async () => { window.unwantedCopy = true } } });
      window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('.race-analysis-share'), 'race-analysis-share').connect();
    JS
    click_button "Share…"
    assert_equal PublicSite.url(debrief_race_path(races(:bahrain_2026))), page.evaluate_script("window.sharedDebrief.url")
    assert_nil page.evaluate_script("window.unwantedCopy")
    assert_no_text "Link copied."
  end

  test "model and ranking prose starts collapsed and is keyboard accessible" do
    RaceExpectations::Dataset.stub(:before, @history) do
      visit race_path(races(:bahrain_2026), anchor: "race-analysis")
      assert_no_text "A strong driver recovering from a poor qualifying"
      assert_no_text "Fit on"
      assert_no_text "not poor driving"
      assert_selector ".race-expectations-leaders-note", text: "3/4 entrants assessed. DNFs excluded."

      model_summary = find("#race-expectations-info summary")
      model_summary.send_keys(:enter)
      assert_selector "#race-expectations-info[open]"
      assert_text "Fit on"
      assert_selector ".race-analysis-coverage", text: "qualifying results"
      model_summary.send_keys(:enter)
      assert_no_selector "#race-expectations-info[open]"
      assert_no_text "Fit on"

      ranking_summary = find(".race-expectations-ranking-info summary")
      ranking_summary.send_keys(:space)
      assert_text "not poor driving"
      ranking_summary.send_keys(:space)
      assert_no_text "not poor driving"
    end
  end

  test "sharing opens a dedicated debrief and keeps the normal race page reachable" do
    RaceExpectations::Dataset.stub(:before, @history) do
      visit race_path(races(:bahrain_2026), tab: "qualifying")
      wait_for_stimulus "tab-table", "#race-classification"
      click_button "Debrief"
      find(".race-analysis-share summary").click
      click_link "Open debrief page"
      assert_current_path debrief_race_path(races(:bahrain_2026))
      assert_selector ".race-debrief-identity h1", text: races(:bahrain_2026).circuit.name
      assert_selector ".race-expectations-leaderboard", count: 2
      assert_no_selector "[data-controller='tab-table']"
      click_link "Results & qualifying →"
      assert_current_path race_path(races(:bahrain_2026)) do |uri|
        uri.fragment == "race-classification"
      end
      assert_selector "#race-classification table"
    end
  end

  test "shared debrief shows the rankings on the first phone screen" do
    RaceExpectations::Dataset.stub(:before, @history) do
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
      visit debrief_race_path(races(:bahrain_2026))
      assert_selector ".race-expectations-leaderboard", count: 2
      assert_operator page.evaluate_script("document.querySelector('.race-expectations-leader-grid').getBoundingClientRect().top"), :<, 650
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 390
      assert_equal "", page.evaluate_script("window.location.hash")
    end
  end

  test "dedicated debrief and info controls work without JavaScript" do
    RaceExpectations::Dataset.stub(:before, @history) do
      page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
      visit debrief_race_path(races(:bahrain_2026))
      assert_selector ".race-expectations-leaderboard", count: 2
      assert_selector ".race-expectations-table tbody tr", count: 4
      assert_no_text "Fit on"
      find("#race-expectations-info summary").click
      assert_text "Fit on"
      find(".race-analysis-share summary").click
      assert_equal PublicSite.url(debrief_race_path(races(:bahrain_2026))), find("#race-analysis-share-url").value
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
  end

  test "phone model info expands in flow without covering the rankings" do
    RaceExpectations::Dataset.stub(:before, @history) do
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
      visit race_path(races(:bahrain_2026), anchor: "race-analysis")
      assert_no_text "A strong driver recovering"
      find("#race-expectations-info summary").click
      assert_text "A strong driver recovering"
      info_bottom = page.evaluate_script("document.querySelector('#race-expectations-info').getBoundingClientRect().bottom")
      cards_top = page.evaluate_script("document.querySelector('.race-expectations-leader-grid').getBoundingClientRect().top")
      assert_operator cards_top, :>=, info_bottom
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 390
      find("#race-expectations-info summary").click
      assert_no_text "A strong driver recovering"
    end
  end

  test "debrief uses shared palette and brings the grid closer to the heading" do
    RaceExpectations::Dataset.stub(:before, @history) do
      visit race_path(races(:bahrain_2026), anchor: "race-analysis")
      assert_equal "rgb(0, 210, 106)", page.evaluate_script("getComputedStyle(document.querySelector('.race-analysis-positive .race-expectations-leader-gap')).color")
      assert_equal "rgb(225, 6, 0)", page.evaluate_script("getComputedStyle(document.querySelector('.race-analysis-negative .race-expectations-leader-gap')).color")
      assert_equal "22px", page.evaluate_script("getComputedStyle(document.querySelector('#race-analysis-title')).fontSize")
      heading_top = page.evaluate_script("document.querySelector('#race-analysis-title').getBoundingClientRect().top")
      grid_top = page.evaluate_script("document.querySelector('.race-expectations-table').getBoundingClientRect().top")
      assert_operator grid_top - heading_top, :<, 580
    end
  end

  test "race tabs work on phones and desktop and resize the hidden Elo chart" do
    [320, 390, 1400].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844, deviceScaleFactor: 1, mobile: width < 769)
      visit race_path(races(:bahrain_2026))
      wait_for_stimulus "tab-table", "#race-classification"
      assert_no_selector ".race-section-nav"
      assert_selector "button[aria-selected='true']", text: "Race", exact_text: true
      assert_no_selector "#race-analysis"
      assert_no_selector "#race-elo-changes"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width
      page.save_screenshot(Rails.root.join("tmp/screenshots/mobile-polish/race-tabs-#{width}.png"))

      click_button "Debrief"
      assert_selector "#race-analysis-title", text: "Race debrief"
      assert_no_selector "#race-classification-race-panel"
      assert_equal "debrief", page.evaluate_script("new URL(location.href).searchParams.get('tab')")
      page.refresh
      assert_selector "button[aria-selected='true']", text: "Debrief"
      click_button "Elo", exact: true
      assert_selector "#race-elo-changes canvas"
      Selenium::WebDriver::Wait.new(timeout: 5).until do
        page.evaluate_script(<<~JS)
          (() => {
            const el = document.querySelector('#race-elo-changes [_echarts_instance_]')
            const chart = el && window.echarts?.getInstanceByDom(el)
            return chart && chart.getWidth() > 200 && Math.abs(chart.getWidth() - el.clientWidth) < 2
          })()
        JS
      end
      page.save_screenshot(Rails.root.join("tmp/screenshots/mobile-polish/race-elo-tab-#{width}.png"))
      click_button "Race", exact: true
      assert_selector "#race-classification-race-panel"
      assert_no_selector "#race-elo-changes"
    end
  end

  test "legacy section links select the right tab and do not force it after switching" do
    { "race-analysis" => "Debrief", "race-elo-changes" => "Elo" }.each do |anchor, label|
      visit race_path(races(:bahrain_2026), anchor: anchor)
      assert_selector "button[aria-selected='true']", text: label, exact_text: true
      assert_selector "##{anchor}"
      click_button "Race", exact: true
      assert_selector "#race-classification-race-panel"
      assert_equal "#race-classification", page.evaluate_script("location.hash")
      page.refresh
      assert_selector "button[aria-selected='true']", text: "Race", exact_text: true
    end
  end
end
