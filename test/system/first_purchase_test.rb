require "application_system_test_case"

class FirstPurchaseTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
    races(:melbourne_2026).update!(date: 2.days.from_now.to_date)
    @driver = drivers(:leclerc)
    @driver.update!(first_race_date: races(:bahrain_2026).date, last_race_date: races(:bahrain_2026).date)
    @screenshots = Rails.root.join("tmp/screenshots/first-purchase")
    FileUtils.mkdir_p(@screenshots)
  end

  { 320 => 568, 390 => 844, 440 => 956, 768 => 1024, 1400 => 900 }.each do |width, height|
    test "new member buys from the first driver prompt at #{width}px" do
      viewport(width, height: height)
      signup("first-buy-#{width}")
      assert_in_delta 9450, @portfolio.available_cash, 0.01
      assert_equal 0, @portfolio.position_count
      assert_selector ".fantasy-first-buy", text: "No real money"
      assert_no_selector ".fantasy-chart-card"
      assert_no_selector ".fantasy-weekend-chip", text: "Buy first shares"
      capture("portfolio-new-#{width}")
      within(".fantasy-first-buy") { click_link "Buy your first driver" }
      assert_current_path market_fantasy_stock_portfolio_path(@portfolio)
      wait_for_stimulus "stock-cart", ".stock-market-page"
      capture("market-#{width}")
      price = @portfolio.share_price(@driver)
      within("tr[data-driver-id='#{@driver.id}']") do
        find("button[aria-label='Trade Charles Leclerc']").click if width <= 767
        click_button "Buy", exact: true
      end
      assert_equal 0, @portfolio.holdings.count, "Adding a draft must not buy"
      assert_selector "#trade-draft", text: "Charles Leclerc · Buy"
      assert_no_selector "[data-stock-cart-target='marginRow']"
      within("#trade-draft") { fill_in "Quantity", with: "2" }
      find(".fantasy-cart-header").click
      capture("draft-#{width}")
      click_button "Review purchase", exact: true
      assert_selector ".swal2-popup", text: "2 × Charles Leclerc"
      assert_selector ".swal2-popup", text: "Cost: 430 game credits"
      within(".swal2-popup") { assert_no_text "margin" }
      capture("confirmation-#{width}")
      assert_equal 0, @portfolio.holdings.count, "Review must not buy"
      click_button "Keep editing"
      assert_selector ".fantasy-cart-status", text: "Draft kept"
      click_button "Review purchase", exact: true
      click_button "Confirm purchase", exact: true
      assert_current_path fantasy_overview_path(@user.username)
      assert_text "Bought 2x Charles Leclerc"
      holding = @portfolio.active_longs.find_by!(driver: @driver)
      assert_equal 2, holding.quantity
      assert_in_delta price, holding.entry_price, 0.01
      assert_in_delta 9450 - 2 * price, @portfolio.wallet.reload.cash, 0.01
      assert_equal 1, @portfolio.transactions.where(kind: "buy").count
      assert_nil page.evaluate_script("sessionStorage.getItem('f1elo:stock-cart:#{@portfolio.id}')")
      assert_no_selector ".fantasy-first-buy"
      assert_selector ".driver-card", text: "Leclerc"
      capture("portfolio-bought-#{width}")
      page.refresh
      assert_selector ".driver-card", text: "Leclerc"
      assert_equal 1, @portfolio.transactions.where(kind: "buy").count
    end
  end

  test "head to head hands a mobile member directly to their chosen driver without buying" do
    viewport(390, height: 844)
    9.times do |i|
      driver = @driver.dup
      driver.assign_attributes(driver_ref: "first_buy_driver_#{i}", forename: "Test", surname: "Driver #{i}", code: "T#{i}", elo_v2: 1900 + i * 20)
      driver.save!
      SeasonDriver.create!(driver: driver, season: seasons(:season_2026), constructor: constructors(:ferrari), active: true)
    end
    signup("h2h-first-buy")
    find(".fantasy-weekend-chip", text: "Head-to-Head").click
    12.times do |round|
      assert_selector ".page-hero-meta", text: "Round #{round + 1} of 12"
      wait_for_stimulus "h2h-pick", ".h2h-cards"
      cards = all("button.h2h-card")
      (cards.find { |card| card.text.include?(@driver.fullname) } || cards.first).click
    end
    assert_selector ".h2h-buy-prompt", text: "+50 credits earned"
    assert_selector ".h2h-buy-prompt", text: "You picked Charles Leclerc"
    assert_in_delta 9500, @portfolio.wallet.reload.cash, 0.01
    capture("h2h-finish-390")
    within(".h2h-buy-prompt") { click_link "Buy Leclerc shares" }
    wait_for_stimulus "stock-cart", ".stock-market-page"
    assert_selector "#driver-#{@driver.id}.trade-options-open"
    assert_no_selector ".fantasy-cart-item"
    assert_equal 0, @portfolio.position_count
    assert_equal 0, @portfolio.transactions.count
    capture("h2h-market-390")
    within("#driver-#{@driver.id}") { click_button "Buy", exact: true }
    click_button "Review purchase", exact: true
    click_button "Confirm purchase", exact: true
    assert_current_path fantasy_overview_path(@user.username)
    assert_equal 1, @portfolio.active_longs.find_by!(driver: @driver).quantity
    assert_in_delta 9285, @portfolio.wallet.reload.cash, 0.01
  end

  test "deep links preserve drafts and remain usable on phones and desktop" do
    sign_in_as users(:codex)
    portfolio = fantasy_stock_portfolios(:codex_stock_2026)
    [320, 390, 1400].each do |width|
      viewport(width)
      visit market_fantasy_stock_portfolio_path(portfolio, driver: @driver.id, anchor: "driver-#{@driver.id}")
      wait_for_stimulus "stock-cart", ".stock-market-page"
      assert_selector "#driver-#{@driver.id}.market-driver-selected"
      within("#driver-#{@driver.id}") { assert_button "Buy", disabled: false }
      assert_no_selector ".fantasy-cart-item"
      capture("focused-market-#{width}")
    end
    within("#driver-#{@driver.id}") { click_button "Buy", exact: true }
    visit market_fantasy_stock_portfolio_path(portfolio, driver: drivers(:piastri).id)
    wait_for_stimulus "stock-cart", ".stock-market-page"
    assert_selector ".fantasy-cart-item", text: "Charles Leclerc · Buy", count: 1
    assert_equal "1", find("input[name='orders[][quantity]']", visible: false).value
    assert_no_selector ".fantasy-cart-item", text: "Oscar Piastri"
  end

  test "mixed buys and shorts keep margin visible and use trade confirmation" do
    viewport(390)
    sign_in_as users(:codex)
    portfolio = fantasy_stock_portfolios(:codex_stock_2026)
    visit market_fantasy_stock_portfolio_path(portfolio)
    page.execute_script("sessionStorage.clear()")
    page.refresh
    wait_for_stimulus "stock-cart", ".stock-market-page"
    find("button[aria-label='Trade Charles Leclerc']").click
    within("#driver-#{@driver.id}") { click_button "Buy", exact: true }
    find(".fantasy-cart-toggle").click
    find("button[aria-label='Trade Oscar Piastri']").click
    within("#driver-#{drivers(:piastri).id}") { click_button "Short", exact: true }
    find(".fantasy-cart-toggle").click
    assert_selector "[data-stock-cart-target='marginRow']", text: "102.5"
    click_button "Review trades", exact: true
    assert_selector ".swal2-popup", text: "Reserve as margin: 102.5"
    assert_button "Confirm trades"
    assert_no_button "Confirm purchase"
    click_button "Keep editing"
    assert_equal 0, portfolio.active_holdings.where(driver: [@driver, drivers(:piastri)]).count
  end

  private

  def signup(username)
    visit new_user_registration_path
    page.execute_script("sessionStorage.clear()")
    fill_in "Username", with: username
    fill_in "Email", with: "#{username}@example.test"
    fill_in "Password", with: "test-password-123"
    find("#user_terms_accepted").check
    click_button "Join F1 Elo"
    assert_current_path fantasy_overview_path(username)
    @user = User.find_by!(username: username)
    @portfolio = @user.fantasy_stock_portfolio_for(seasons(:season_2026))
    assert @portfolio
    assert_selector ".fantasy-first-buy"
    if has_css?(".flash-dismiss", wait: 1)
      find(".flash-dismiss").click
      assert_no_selector ".flash"
    end
  end

  def capture(name)
    page.driver.browser.execute_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      const popup = document.querySelector('.swal2-popup')
      const animations = popup ? popup.getAnimations({subtree: true}).filter(a => a.effect.getTiming().iterations !== Infinity) : []
      Promise.allSettled(animations.map(a => a.finished)).then(done)
    JS
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1"), "No page overflow: #{name}"
    assert page.evaluate_script("Array.from(document.querySelectorAll('.table-scroll-wrapper')).filter(el => el.getClientRects().length).every(el => el.scrollWidth <= el.clientWidth + 1)"), "No table overflow: #{name}"
    page.save_screenshot(@screenshots.join("#{name}.png"))
  end
end
