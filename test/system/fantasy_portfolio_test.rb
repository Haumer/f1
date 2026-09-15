require "application_system_test_case"

class FantasyPortfolioTest < ApplicationSystemTestCase
  setup do
    Capybara.reset_sessions!
    # Start the real login flow with no cookies left from another browser test.
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
    @owner = users(:codex)
    @owner.update!(username: "anotherfantasyplayer", public_profile: true)
    @viewer = users(:latejoin)
    FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
  end

  test "member can view a public portfolio and return to their own dashboard" do
    visit fantasy_overview_path(@owner.username)
    assert_selector ".fantasy-public-challenge"
    within ".fantasy-public-challenge" do
      assert_link "Play free", href: new_user_registration_path
    end

    sign_in_as @viewer
    visit fantasy_overview_path(@owner.username)

    assert_selector ".fantasy-dashboard-name", text: @owner.username
    assert_no_selector ".fantasy-public-challenge"
    assert_no_selector ".fantasy-visibility-inline-form"
    assert_no_selector ".fantasy-pitwall-weekend"
    within ".fantasy-dashboard-header" do
      assert_text /Public portfolio/i
      assert_link "My portfolio", href: fantasy_overview_path(@viewer.username)
      assert_no_link "Market"
    end
    page.save_screenshot(Rails.root.join("tmp/screenshots/fantasy-member-desktop.png"))

    within ".fantasy-dashboard-header" do
      click_link "My portfolio"
    end

    assert_current_path fantasy_overview_path(@viewer.username)
    assert_selector ".fantasy-dashboard-name", text: @viewer.username
    assert_selector ".fantasy-visibility-inline-form"
    assert_no_selector ".fantasy-public-challenge"
    within ".fantasy-dashboard-header" do
      assert_link "Market", href: market_fantasy_stock_portfolio_path(fantasy_stock_portfolios(:latejoin_stock_2026))
      assert_no_link "My portfolio"
    end
  end

  test "member portfolio navigation fits on a phone" do
    sign_in_as @viewer
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit fantasy_overview_path(@owner.username)

    assert_no_selector ".fantasy-public-challenge"
    within ".fantasy-dashboard-header" do
      assert_link "My portfolio", href: fantasy_overview_path(@viewer.username)
      assert_link "Leaderboard", href: combined_leaderboard_path
    end
    assert_equal 390, page.evaluate_script("window.innerWidth")
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"),
                    :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
    page.save_screenshot(Rails.root.join("tmp/screenshots/fantasy-member-mobile.png"))
  end
end
