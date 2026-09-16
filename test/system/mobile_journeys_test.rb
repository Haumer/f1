require "application_system_test_case"

class MobileJourneysTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
    drivers(:verstappen).update!(first_race_date: races(:bahrain_2026).date, last_race_date: races(:bahrain_2026).date)
    FileUtils.mkdir_p(Rails.root.join("tmp/screenshots/mobile-polish"))
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
  end

  [320, 390, 430].each do |width|
    test "race catch-up and driver round trip at #{width}px" do
      phone(width)
      visit race_path(races(:bahrain_2026), source: "journey", anchor: "race-classification")
      wait_for_stimulus "tab-table", "#race-classification"
      assert_fits(width)
      assert_selector "button[role='tab'][aria-selected='true']", text: "Race"
      assert_operator dimension(".menu-toggle", "width"), :>=, 44
      assert_operator dimension(".menu-toggle", "height"), :>=, 44
      assert_operator dimension("#race-classification .table-tab", "height"), :>=, 44

      click_button "Qualifying"
      assert_selector "button[role='tab'][aria-selected='true']", text: "Qualifying"
      assert_equal "qualifying", page.evaluate_script("new URL(location.href).searchParams.get('tab')")
      assert_equal "journey", page.evaluate_script("new URL(location.href).searchParams.get('source')")
      assert_equal "#race-classification", page.evaluate_script("location.hash")
      assert_selector "#race-classification-qualifying-panel", text: "1:28.789"
      page.save_screenshot(Rails.root.join("tmp/screenshots/mobile-polish/qualifying-#{width}.png"))

      within "#race-classification-qualifying-panel" do
        find("a[href='#{driver_path(drivers(:verstappen))}']").click
      end
      assert_current_path driver_path(drivers(:verstappen))
      page.go_back
      assert_selector "button[role='tab'][aria-selected='true']", text: "Qualifying"
      page.refresh
      assert_selector "button[role='tab'][aria-selected='true']", text: "Qualifying"
      assert_fits(width)
    end
  end

  test "phone race page exposes results earlier without removing context" do
    phone(390)
    visit race_path(races(:bahrain_2026))
    assert_selector "#race-classification"
    assert_operator page.evaluate_script("document.querySelector('#race-classification').getBoundingClientRect().top"), :<, 620
    assert_selector ".race-stats-row", text: "AVG ELO"
    assert_no_selector ".race-section-nav"
    assert_button "Race"
    assert_button "Debrief"
    assert_selector "a.race-nav-btn[aria-label^='Next race:']"
    assert_fits(390)
    page.save_screenshot(Rails.root.join("tmp/screenshots/mobile-polish/race-390.png"))
  end

  test "race stats keep three equal cards on one row throughout mobile widths" do
    [320, 390, 430, 440, 480, 600, 768].each do |width|
      phone(width)
      visit race_path(races(:bahrain_2026))
      assert_selector ".race-stats-row .race-stat-card", count: 3
      cards = race_stat_bounds
      assert_equal 1, cards.map { |card| card["top"] }.uniq.size, "one row at #{width}px"
      assert_equal 3, cards.map { |card| card["left"] }.uniq.size, "three columns at #{width}px"
      cards.each { |card| assert_in_delta cards.first["width"], card["width"], 1, "card width at #{width}px" }
      assert_no_selector ".race-stats-row", text: "NON-FINISHES"
      assert_selector "#race-classification [data-tab='race'] td", text: "DNF"
      assert page.evaluate_script("Array.from(document.querySelectorAll('.race-stat-label')).every(el => el.scrollWidth <= el.clientWidth)"), "readable labels at #{width}px"
      assert_fits(width)
      page.save_screenshot(Rails.root.join("tmp/screenshots/mobile-polish/race-stats-#{width}.png")) if width == 440
    end
  end

  test "race stats keep three columns on desktop including just above the mobile breakpoint" do
    [769, 1024, 1400].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
      visit race_path(races(:bahrain_2026))
      assert_selector ".race-stats-row .race-stat-card", count: 3
      assert_equal 1, race_stat_bounds.map { |card| card["top"] }.uniq.size, "single row at #{width}px"
      assert_equal 3, race_stat_bounds.map { |card| card["left"] }.uniq.size, "three columns at #{width}px"
    end
  end

  test "driver search survives opening a result and can be cleared on mobile" do
    phone(390)
    visit drivers_path
    wait_for_stimulus "search-form", ".search-form"
    fill_in "Search drivers", with: "Verstappen"
    within "turbo-frame#drivers" do
      assert_selector ".driver-search-status", text: "Results for “Verstappen”"
      assert_no_text "Norris"
      click_link "M.Verstappen"
    end
    assert_current_path driver_path(drivers(:verstappen))
    page.go_back
    assert_field "Search drivers", with: "Verstappen"
    page.refresh
    assert_field "Search drivers", with: "Verstappen"
    assert_selector ".driver-search-status", text: "Verstappen"
    click_link "Clear search"
    assert_current_path drivers_path
    assert_field "Search drivers", with: ""
    assert_no_selector ".driver-search-status"
    assert_fits(390)
  end

  test "desktop race tabs retain the full table and support a keyboard" do
    visit race_path(races(:bahrain_2026))
    wait_for_stimulus "tab-table", "#race-classification"
    assert_no_selector ".menu-toggle"
    assert_selector "#race-classification-race-panel th", text: "GRID"
    assert_selector "#race-classification-race-panel th", text: "SEASON PTS"
    assert_equal "40px", page.evaluate_script("getComputedStyle(document.querySelector('.race-hero h1')).fontSize")
    find("button[role='tab']", text: "Race", exact_text: true).send_keys(:arrow_right)
    assert_selector "button[aria-selected='true']", text: "Qualifying"
    assert_equal "race-classification-qualifying-tab", page.evaluate_script("document.activeElement.id")
    find("button[role='tab']", text: "Qualifying").send_keys(:home)
    assert_selector "button[aria-selected='true']", text: "Race"
    assert_fits(page.evaluate_script("window.innerWidth"))
    page.save_screenshot(Rails.root.join("tmp/screenshots/mobile-polish/race-desktop.png"))
  end

  test "unavailable race sessions are disabled and invalid tabs fall back safely" do
    visit race_path(races(:melbourne_2026), tab: "qualifying")
    wait_for_stimulus "tab-table", "#race-classification"
    assert_button "Qualifying", disabled: true
    assert_selector "button[aria-selected='true']", text: "Race"
    find("button[role='tab']", text: "Race", exact_text: true).send_keys(:arrow_right)
    assert_selector "button[aria-selected='true']", text: "Race"
    visit race_path(races(:bahrain_2026), tab: "unknown")
    assert_selector "button[aria-selected='true']", text: "Race"
  end

  test "mobile menu supports the history journey and releases focus and scrolling" do
    phone(320)
    visit root_path
    wait_for_stimulus "navbar", ".navbar"
    find(".menu-toggle").click
    assert_selector ".navbar.menu-open"
    find(".nav-dropdown-toggle", text: "HISTORY").click
    find("a[href='#{best_pairings_constructors_path}']").click
    assert_current_path best_pairings_constructors_path
    assert_no_selector ".navbar.menu-open"
    assert_equal "", page.evaluate_script("document.body.style.overflow")
    find(".menu-toggle").click
    page.driver.browser.action.send_keys(:escape).perform
    assert_no_selector ".navbar.menu-open"
    assert_equal "menu-toggle", page.evaluate_script("document.activeElement.className")
    assert_equal "", page.evaluate_script("document.body.style.overflow")
    assert_fits(320)
  end

  test "an open phone menu does not lock scrolling after resizing to desktop" do
    phone(390)
    visit root_path
    wait_for_stimulus "navbar", ".navbar"
    find(".menu-toggle").click
    assert_selector ".navbar.menu-open"
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    assert_no_selector ".navbar.menu-open"
    assert_no_selector ".menu-toggle"
    assert_selector ".navbar .links", text: "HISTORY"
    assert_equal "", page.evaluate_script("document.body.style.overflow")
  end

  test "fantasy signup on a small phone keeps password entry clear and usable" do
    phone(320)
    visit fantasy_home_path
    within ".fantasy-landing-hero" do
      click_link "Play free"
    end
    assert_current_path new_user_registration_path
    assert_fits(320)
    wait_for_stimulus "password-visibility", ".password-field"
    fill_in "Username", with: "mobile_racer"
    fill_in "Email", with: "mobile-racer@example.com"
    fill_in "Password", with: "password123"
    click_button "Show"
    assert_equal "text", find("#user_password")[:type]
    assert_equal "password123", find("#user_password").value
    assert_selector ".password-toggle[aria-pressed='true']", text: "Hide"
    click_button "Hide"
    assert_equal "password", find("#user_password")[:type]
    assert_equal "16px", page.evaluate_script("getComputedStyle(document.querySelector('#user_password')).fontSize")
    page.save_screenshot(Rails.root.join("tmp/screenshots/mobile-polish/signup-320.png"))
    check "user_terms_accepted"
    click_button "Join F1 Elo"
    assert_current_path fantasy_overview_path("mobile_racer")
    assert_selector ".fantasy-dashboard-name", text: "mobile_racer"
    assert_no_selector ".fantasy-public-challenge"
    assert_fits(320)
  end

  test "password visibility resets before Turbo caches the form" do
    visit new_user_session_path
    wait_for_stimulus "password-visibility", ".password-field"
    fill_in "Password", with: "password123"
    click_button "Show"
    page.execute_script("document.dispatchEvent(new Event('turbo:before-cache'))")
    assert_equal "password", find("#user_password")[:type]
    assert_selector ".password-toggle[aria-pressed='false']", text: "Show"
    assert_operator dimension(".devise-card", "width"), :<=, 420
    assert_equal "15px", page.evaluate_script("getComputedStyle(document.querySelector('#user_password')).fontSize")
    page.save_screenshot(Rails.root.join("tmp/screenshots/mobile-polish/signin-desktop.png"))
  end

  test "portfolio details remember the selected tab" do
    phone(390)
    sign_in_as users(:codex)
    visit fantasy_overview_path(users(:codex).username)
    wait_for_stimulus "tab-table", "#portfolio-log"
    click_button "Achievements"
    assert_selector "button[aria-selected='true']", text: "Achievements"
    assert_equal "achievements", page.evaluate_script("new URL(location.href).searchParams.get('view')")
    page.refresh
    assert_selector "button[aria-selected='true']", text: "Achievements"
    assert_selector "#portfolio-log-achievements-panel"
    assert_fits(390)
  end

  private

  def race_stat_bounds
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('.race-stats-row .race-stat-card')).map(el => {
        const r = el.getBoundingClientRect()
        return { top: Math.round(r.top), left: Math.round(r.left), width: r.width }
      })
    JS
  end

  def phone(width)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844, deviceScaleFactor: 1, mobile: true)
  end

  def dimension(selector, dimension)
    page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect()[#{dimension.to_json}]")
  end

  def assert_fits(width)
    assert_equal width, page.evaluate_script("window.innerWidth")
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width
  end
end
