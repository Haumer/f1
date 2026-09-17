require "application_system_test_case"

class MarketPolishTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
    @portfolio = fantasy_stock_portfolios(:codex_stock_2026)
    @race = races(:melbourne_2026)
    @race.update!(date: 2.days.from_now.to_date)
    @driver = drivers(:leclerc)
    @driver.update!(first_race_date: races(:bahrain_2026).date, last_race_date: races(:bahrain_2026).date)
    FileUtils.mkdir_p(Rails.root.join("tmp/screenshots/market-polish"))
    sign_in_as users(:codex)
    visit market_fantasy_stock_portfolio_path(@portfolio)
    page.execute_script("sessionStorage.clear()")
    page.refresh
    wait_for_stimulus "stock-cart", ".stock-market-page"
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
  end

  test "compact cart and editable quantities fit phones and retain the desktop sidebar" do
    [320, 390, 1400].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: width < 769)
      visit market_fantasy_stock_portfolio_path(@portfolio)
      wait_for_stimulus "stock-cart", ".stock-market-page"
      if width < 861
        assert_no_selector "#trade-draft"
        assert_operator page.evaluate_script("document.querySelector('.fantasy-market-sidebar').getBoundingClientRect().height"), :<, 90
      else
        assert_selector "#trade-draft"
        assert_no_selector ".fantasy-cart-toggle"
      end
      page.save_screenshot(Rails.root.join("tmp/screenshots/market-polish/market-#{width}.png"))
      within driver_row do
        click_button "Long", exact: true
      end
      click_button "Review", exact: false if width < 861
      assert_selector "#trade-draft", text: "Charles Leclerc · Long"
      within("#trade-draft") { fill_in "Quantity", with: "2" }
      find(".fantasy-cart-header").click
      assert_equal "2", find("input[name='orders[][quantity]']", visible: false).value
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width
      page.save_screenshot(Rails.root.join("tmp/screenshots/market-polish/cart-#{width}.png"))
      within "#trade-draft" do
        click_button "Clear", exact: true
      end
    end
  end

  test "draft survives a driver round trip and refresh with current prices" do
    within(driver_row) { click_button "Long", exact: true }
    within(driver_row) { find("a[href='#{driver_path(@driver)}']").click }
    assert_current_path driver_path(@driver)
    page.go_back
    assert_selector "#trade-draft", text: "Charles Leclerc · Long"
    @driver.update!(elo_v2: @driver.elo_v2 + 100)
    page.refresh
    assert_selector ".fantasy-cart-status", text: "Draft restored"
    assert_in_delta @portfolio.share_price(@driver), find("input[name='orders[][quoted_price]']", visible: false).value.to_f
  end

  test "short review uses margin current quotes and clears the draft only after success" do
    within(driver_row) { click_button "Short", exact: true }
    price = @portfolio.share_price(@driver)
    assert_in_delta price * FantasyStockPortfolio::COLLATERAL_RATIO, find("[data-stock-cart-target='cartTotal']").text.delete(",").to_f, 0.01
    @driver.update!(elo_v2: @driver.elo_v2 + 100)
    click_button "Review trades", exact: true
    assert_selector ".swal2-popup", text: "Reserve as margin"
    click_button "Keep editing"
    assert_selector ".fantasy-cart-status", text: "Draft kept"
    assert page.evaluate_script("sessionStorage.getItem('f1elo:stock-cart:#{@portfolio.id}') !== null")
    click_button "Review trades", exact: true
    click_button "Execute trades", exact: true
    assert_current_path fantasy_overview_path(users(:codex).username)
    assert_text "Opened"
    assert_nil page.evaluate_script("sessionStorage.getItem('f1elo:stock-cart:#{@portfolio.id}')")
  end

  test "closed market and unavailable quote never submit a saved draft" do
    within(driver_row) { click_button "Long", exact: true }
    page.execute_script("window.fetch = async () => { throw new Error('offline') }")
    click_button "Review trades", exact: true
    assert_selector ".fantasy-cart-status", text: "Could not check current prices"
    assert_selector "#trade-draft", text: "Charles Leclerc"
    @race.update!(date: Date.yesterday)
    page.refresh
    assert_no_selector ".fantasy-cart-item"
    assert_text "Market closed"
    assert_nil page.evaluate_script("sessionStorage.getItem('f1elo:stock-cart:#{@portfolio.id}')")
  end

  private

  def driver_row
    "tr[data-driver-id='#{@driver.id}']"
  end
end
