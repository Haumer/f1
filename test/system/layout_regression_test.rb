require "application_system_test_case"

class LayoutRegressionTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
    @user = users(:codex)
    @user.update!(username: "maximum_username_example", public_profile: true, created_at: Time.current)
    @race = races(:melbourne_2026)
    @race.update!(date: Date.current + 5, time: "14:00:00")
    fantasy_stock_transactions(:codex_stock_buy_ver).update!(kind: "buy", created_at: Time.current)
    fantasy_stock_transactions(:codex_stock_short_nor).update!(kind: "short_open", created_at: Time.current)
    @screens = Rails.root.join("tmp/screenshots/layout-regression")
    FileUtils.mkdir_p(@screens)
  end

  teardown do
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
  end

  test "homepage activity has a deliberate mobile header and readable stats with or without picks" do
    drivers(:piastri).update!(forename: "Gabriel", surname: "Bortoleto")
    [false, true].each do |with_picks|
      RacePick.create!(user: @user, race: @race, picks: [{ driver_id: drivers(:verstappen).id, position: 1, source: "manual" }]) if with_picks
      [320, 390, 440, 600, 768, 1024, 1400].each do |width|
        viewport(width)
        visit root_path
        assert_selector ".activity-stat", count: with_picks ? 3 : 2
        assert_page_fits(width)
        assert_tables_fit(width)
        assert_content_fits ".activity-strip, .latest-result-label, .leaderboard-preview-row"
        if width <= 600
          assert page.evaluate_script(<<~JS), "label/link share a header, stats follow at #{width}px"
            (() => {
              const label = document.querySelector('.activity-strip-label').getBoundingClientRect();
              const link = document.querySelector('.activity-strip-link').getBoundingClientRect();
              const stats = document.querySelector('.activity-strip-stats').getBoundingClientRect();
              return link.height >= 44 && label.right <= link.left && label.top < link.bottom && stats.top >= link.bottom;
            })()
          JS
        end
        assert page.evaluate_script(<<~JS), "activity text contrast"
          (() => {
            const l = color => { const c=color.match(/[0-9.]+/g).slice(0,3).map(v=>{v=Number(v)/255;return v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4});return c[0]*0.2126+c[1]*0.7152+c[2]*0.0722; };
            const bg=l(getComputedStyle(document.querySelector('.activity-strip')).backgroundColor);
            return [...document.querySelectorAll('.activity-strip-label,.activity-stat-label,.activity-strip-link')].every(el=>(l(getComputedStyle(el).color)+0.05)/(bg+0.05)>=4.5);
          })()
        JS
        screenshot("home-#{with_picks ? 'picks' : 'no-picks'}", width, ".activity-strip")
      end
    end
  end

  test "race and qualifying tables fit inside their panels at responsive boundaries" do
    [drivers(:verstappen), drivers(:norris)].each_with_index do |driver, index|
      DriverBadge.create!(driver: driver, key: "circuit_king_#{races(:bahrain_2026).circuit_id}",
                          label: "Circuit King", tier: index.zero? ? "gold" : "silver", value: 5,
                          description: "Five wins at Bahrain International Circuit: 2010, 2012, 2015, 2018, 2020")
    end
    [320, 390, 440, 575, 576, 600, 767, 768, 861, 991, 992, 1024, 1400].each do |width|
      viewport(width)
      visit race_path(races(:bahrain_2026))
      wait_for_stimulus "result-details", "#race-classification-race-panel table"
      ["Race", "Qualifying"].each do |tab|
        click_button tab, exact: true
        if width < 992
          find("button[aria-label='Details for Max Verstappen']").click
          assert_selector ".result-details-row", text: tab == "Race" ? "Grid" : "Q3"
        end
        assert_page_fits(width)
        assert_tables_fit(width)
        assert_content_fits ".race-results--tabbed .col-name, .race-results--tabbed .col-elo"
        screenshot(tab.downcase, width, "#race-classification-#{tab.downcase}-panel")
      end
    end
  end

  test "long usernames keep portfolio and leaderboard contained and sell controls usable" do
    sign_in_as @user
    [320, 390, 440, 768, 861, 1024, 1400].each do |width|
      viewport(width)
      visit fantasy_overview_path(@user.username)
      wait_for_stimulus "sell-qty", ".sell-qty-form[data-controller]"
      assert_page_fits(width)
      assert_content_fits ".fantasy-dashboard-name, .driver-card-action"
      if width <= 991
        assert page.evaluate_script(<<~JS), "sell controls have phone-sized targets"
          [...document.querySelectorAll('.sell-qty-stepper button')].every(el=>{const r=el.getBoundingClientRect();return r.width>=44 && r.height>=44})
        JS
      end
      find("button[aria-label='Decrease quantity for Max Verstappen']").click
      assert_equal "4", find("input[aria-label='Quantity to sell for Max Verstappen']").value
      assert_button "Sell 4x"
      find("button[aria-label='Increase quantity for Max Verstappen']").click
      assert_equal "5", find("input[aria-label='Quantity to sell for Max Verstappen']").value
      screenshot("portfolio-header", width, ".fantasy-dashboard-header")
      visit combined_leaderboard_path
      assert_selector ".leaderboard-player-name", text: @user.username
      assert_page_fits(width)
      assert_tables_fit(width)
      assert_content_fits ".fantasy-leaderboard-value"
      screenshot("leaderboard", width, ".fantasy-leaderboard-table")
    end
  end

  test "activity keeps driver and achievement subjects visible on phone and desktop" do
    sign_in_as @user
    [320, 390, 440, 768, 1024, 1400].each do |width|
      viewport(width)
      visit fantasy_overview_path(@user.username, view: "activity")
      wait_for_stimulus "tab-table", "#portfolio-log"
      assert_selector "#portfolio-log-activity-panel", text: "Max Verstappen"
      assert_selector "#portfolio-log-activity-panel", text: "Lando Norris"
      assert_selector "#portfolio-log-activity-panel", text: "First Trade"
      assert_tables_fit(width)
      assert_content_fits ".fantasy-activity-table td"
      screenshot("activity", width, "#portfolio-log-activity-panel")
      visit fantasy_activity_path(username: @user.username)
      assert_selector ".fantasy-activity-table", text: "Max Verstappen"
      assert_tables_fit(width)
    end
  end

  test "multiple earned card decks remain inside collection without overlapping" do
    [drivers(:verstappen), drivers(:leclerc)].each do |driver|
      [races(:bahrain_2026), races(:melbourne_2025)].each_with_index do |race, index|
        DriverCard.create!(user: @user, driver: driver, race: race, predicted_position: 1, actual_position: 1,
                           tier: index.zero? ? "legendary" : "gold", earned_at: Time.current - index.days)
      end
    end
    sign_in_as @user
    [320, 390, 440, 600, 601, 768, 1024, 1400].each do |width|
      viewport(width)
      visit driver_cards_path(username: @user.username)
      assert_selector ".dc-deck", count: 2
      wait_for_stimulus "card-deck", ".dc-deck"
      assert_page_fits(width)
      assert page.evaluate_script(<<~JS), "complete decks fit without overlap at #{width}px"
        (() => {
          const root=document.querySelector('.dc-grid').getBoundingClientRect();
          const decks=[...document.querySelectorAll('.dc-grid .dc-deck')].map(el=>el.getBoundingClientRect());
          return decks.every(r=>r.left>=root.left-1 && r.right<=root.right+1) && decks.every((a,i)=>decks.slice(i+1).every(b=>a.right<=b.left+1 || b.right<=a.left+1 || a.bottom<=b.top+1 || b.bottom<=a.top+1));
        })()
      JS
      screenshot("cards", width, ".dc-collection")
    end
  end

  private

  def assert_page_fits(width)
    # innerWidth includes Linux's scrollbar; clientWidth is the space content
    # must actually fit. macOS overlay scrollbars do not reserve those pixels.
    assert_equal width, page.evaluate_script("window.innerWidth"), "actual emulated viewport"
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end

  def assert_tables_fit(width)
    failures = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.table-scroll-wrapper')].filter(el=>el.getBoundingClientRect().width>0 && el.scrollWidth>el.clientWidth+1).map(el=>({table:el.querySelector('table')?.className, available:el.clientWidth, content:el.scrollWidth}))
    JS
    assert_empty failures, "nested table overflow at #{width}px: #{failures}"
  end

  def assert_content_fits(selector)
    failures = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(#{selector.to_json})].filter(el=>el.getBoundingClientRect().width>0 && el.scrollWidth>el.clientWidth+1).map(el=>({class:el.className,text:el.textContent.trim().slice(0,60),available:el.clientWidth,content:el.scrollWidth}))
    JS
    assert_empty failures, "clipped component content: #{failures}"
  end

  def screenshot(label, width, selector)
    el = find(selector)
    page.execute_script("arguments[0].scrollIntoView({block:'center',behavior:'instant'})", el)
    el.native.save_screenshot(@screens.join("#{label}-#{width}.png"))
  end
end
