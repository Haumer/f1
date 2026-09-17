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

  test "market prices stay on one line with low cash and double digit holdings" do
    @portfolio.wallet.update!(cash: @portfolio.total_collateral + 146.33)
    fantasy_stock_holdings(:codex_ver_long).update!(quantity: 27)
    drivers(:verstappen).update!(elo_v2: 2470.3)
    @driver.update!(elo_v2: 2431.6)
    [320, 390, 440, 600, 601, 768, 860, 861, 1024, 1400].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 956, deviceScaleFactor: 1, mobile: width <= 860)
      visit market_fantasy_stock_portfolio_path(@portfolio)
      wait_for_stimulus "stock-cart", ".stock-market-page"
      page.save_screenshot(Rails.root.join("tmp/screenshots/market-polish/readability-#{width}.png"))
      assert page.evaluate_script(<<~JS), "prices fit on one line at #{width}px"
        Array.from(document.querySelectorAll('.fantasy-market-price-cell')).every(el => {
          const range = document.createRange(); range.selectNodeContents(el)
          return range.getClientRects().length === 1 && el.getBoundingClientRect().right <= el.closest('td').getBoundingClientRect().right
        })
      JS
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width
      if width <= 600
        assert_selector ".market-mobile-holding", text: "27× LONG"
        assert_no_selector ".market-position-cell"
        assert_no_selector ".market-trade-cell"
        assert page.evaluate_script("Array.from(document.querySelectorAll('.fantasy-market-table tbody tr')).every(el => el.getBoundingClientRect().height <= 80)"), "compact rows at #{width}px"
        assert_operator page.evaluate_script("document.querySelector('.fantasy-market-table').getBoundingClientRect().top"), :<, 320
        within driver_row do
          find("button[aria-label='Trade Charles Leclerc']").click
          assert_button "Long", disabled: true
          assert_button "Short", disabled: false
          assert_text "Long needs 243.16 credits"
        end
      else
        assert_no_selector ".market-trade-toggle"
        assert_selector ".market-position-cell"
      end
      assert_no_selector ".fantasy-market-sidebar" if width <= 860
    end
  end

  test "compact cart and editable quantities fit phones and retain the desktop sidebar" do
    [320, 390, 440, 600, 601, 768, 860, 861, 1400].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: width < 769)
      visit market_fantasy_stock_portfolio_path(@portfolio)
      wait_for_stimulus "stock-cart", ".stock-market-page"
      if width < 861
        assert_no_selector "#trade-draft"
        assert_no_selector ".fantasy-market-sidebar"
      else
        assert_selector "#trade-draft"
        assert_no_selector ".fantasy-cart-toggle"
      end
      page.save_screenshot(Rails.root.join("tmp/screenshots/market-polish/market-#{width}.png"))
      within driver_row do
        find("button[aria-label='Trade Charles Leclerc']").click if width <= 600
        click_button "Long", exact: true
      end
      if width <= 600
        assert_no_selector ".market-trade-cell"
        assert_selector "button[aria-label='Review trade for Charles Leclerc']"
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
      assert_no_selector ".fantasy-market-sidebar" if width <= 860
    end
  end

  test "phone trade disclosures work with keyboard and the draft stays above the footer" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 440, height: 956, deviceScaleFactor: 1, mobile: true)
    visit market_fantasy_stock_portfolio_path(@portfolio)
    wait_for_stimulus "stock-cart", ".stock-market-page"
    find("button[aria-label='Trade Max Verstappen']").click
    assert_selector ".trade-options-open", count: 1
    find("button[aria-label='Trade Charles Leclerc']").click
    assert_selector ".trade-options-open", count: 1
    find(".trade-options-open .stock-trade-buy").send_keys(:escape)
    assert_no_selector ".trade-options-open"
    assert_equal "Trade Charles Leclerc", page.evaluate_script("document.activeElement.getAttribute('aria-label')")
    find("button[aria-label='Trade Charles Leclerc']").send_keys(:enter)
    within(driver_row) { click_button "Long", exact: true }
    assert_selector ".fantasy-cart-toggle", text: "1 trade"
    assert_no_selector "#trade-draft"
    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    assert page.evaluate_script(<<~JS), "review bar is reachable over the footer"
      (() => {
        const button = document.querySelector('.fantasy-cart-toggle')
        const rect = button.getBoundingClientRect()
        return button.contains(document.elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2))
      })()
    JS
    find(".fantasy-cart-toggle").click
    assert_selector "#trade-draft", text: "Charles Leclerc · Long"
    page.save_screenshot(Rails.root.join("tmp/screenshots/market-polish/footer-cart-440.png"))
    within("#trade-draft") { find("button[aria-label='Remove Charles Leclerc']").click }
    assert_no_selector ".fantasy-market-sidebar"
    assert_match "Trade", page.evaluate_script("document.activeElement.getAttribute('aria-label')")

    find("button[aria-label='Trade Charles Leclerc']").click
    within(driver_row) { click_button "Short", exact: true }
    page.refresh
    assert_selector ".fantasy-cart-toggle", text: "1 trade"
    find("button[aria-label='Review trade for Charles Leclerc']").click
    assert_selector "#trade-draft", text: "Charles Leclerc · Short"
    assert_equal "Quantity for Charles Leclerc", page.evaluate_script("document.activeElement.getAttribute('aria-label')")
    @race.update!(date: Date.yesterday)
    page.refresh
    assert_text "Market closed"
    assert_no_selector ".market-trade-toggle"
    assert_no_selector ".fantasy-market-sidebar"
    assert_selector ".market-mobile-holding", text: "5× LONG"
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
