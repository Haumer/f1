require "application_system_test_case"

class PicksPolishTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
    @race = races(:melbourne_2026)
    @race.update!(date: Date.current + 5.days, time: "14:00:00")
    @user = users(:codex)
    @storage_key = "f1elo:picks:#{@user.id}:#{@race.id}"
    18.times do |i|
      driver = Driver.create!(driver_ref: "polish_#{i}", forename: "Test", surname: "Driver #{i + 1}", active: true, elo_v2: 1800 + i)
      SeasonDriver.create!(driver: driver, season: @race.season, constructor: constructors(:ferrari), active: true)
    end
    FileUtils.mkdir_p(Rails.root.join("tmp/screenshots/picks-polish"))
    sign_in_as @user
    visit_editor
    page.execute_script("sessionStorage.clear()")
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
  end

  test "phone review bar and reorder controls fit while desktop keeps its layout" do
    [320, 390, 430, 440, 768, 1400].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 956, deviceScaleFactor: 1, mobile: width <= 768)
      visit_editor
      if width <= 480
        # Stress a full recent-form strip (including a previous-season marker),
        # not only the single result present in the basic fixture.
        page.execute_script(<<~JS)
          const strip = document.querySelector('.picks-card-results');
          const badge = strip.querySelector('.picks-result-badge');
          while (strip.querySelectorAll('.picks-result-badge').length < 5) strip.appendChild(badge.cloneNode(true));
          const year = document.createElement('span'); year.className = 'picks-result-season'; year.textContent = "'25"; strip.appendChild(year);
        JS
        click_button "Recent Form"
        assert page.evaluate_script(<<~JS)
          [...document.querySelectorAll('.picks-card-results > *')].every(el => {
            const card = el.closest('.picks-driver-card').getBoundingClientRect();
            const badge = el.getBoundingClientRect();
            return badge.right <= card.right && badge.left >= card.left;
          })
        JS
      end
      page.save_screenshot(Rails.root.join("tmp/screenshots/picks-polish/picks-#{width}.png"))
      pick drivers(:verstappen)
      pick drivers(:norris)
      if width <= 768
        assert_equal "fixed", page.evaluate_script("getComputedStyle(document.querySelector('.picks-submit-form')).position")
        assert_operator page.evaluate_script("document.querySelector('.picks-submit-form').getBoundingClientRect().height"), :<=, 110
        click_button "Review", exact: true
        assert_equal "pick-order", page.evaluate_script("document.activeElement.id")
        assert_operator page.evaluate_script("document.querySelector('#pick-order').getBoundingClientRect().top"), :>=, 70
        assert_operator page.evaluate_script("document.querySelector('.pick-slot-move').getBoundingClientRect().width"), :>=, 44
      else
        assert_equal "sticky", page.evaluate_script("getComputedStyle(document.querySelector('.picks-submit-form')).position")
        assert_no_button "Review", exact: true
        assert_selector ".pick-slot-team", text: "Red Bull"
        assert_selector ".pick-slot-elo", text: "2400"
        assert_operator page.evaluate_script("getComputedStyle(document.querySelector('.picks-driver-grid')).gridTemplateColumns.split(' ').length"), :>, 2
      end
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width
      move = find("button[aria-label='Move Lando Norris up']")
      move.click
      assert_equal drivers(:norris).id, draft.first["driver_id"]
      assert_selector ".pick-slot-filled:first-child", text: "Lando Norris"
      if width <= 768
        assert page.evaluate_script("Boolean(document.elementFromPoint(#{width - 50}, 930)?.closest('.picks-submit-form'))"), "Save bar must remain above the footer after review"
      end
      page.save_screenshot(Rails.root.join("tmp/screenshots/picks-polish/order-#{width}.png"))
      click_button "Clear", exact: true
    end
  end

  test "draft survives navigation refresh and failed submit but clears after saving" do
    pick drivers(:verstappen)
    assert_nil RacePick.find_by(user: @user, race: @race)
    click_link "Back to portfolio"
    assert_current_path fantasy_overview_path(@user.username)
    page.go_back
    assert_current_path edit_race_picks_path
    wait_for_stimulus "race-picks", "[data-controller='race-picks']"
    assert_selector ".pick-slot-filled", text: "Max Verstappen"
    page.refresh
    assert_selector ".picks-draft-message", text: "Draft restored"
    page.execute_script("document.querySelector('.picks-submit-form').dispatchEvent(new CustomEvent('turbo:submit-end', {bubbles:true, detail:{success:false}}))")
    assert_selector ".picks-draft-message", text: "Picks were not saved"
    assert page.evaluate_script("sessionStorage.getItem(#{@storage_key.to_json}) !== null")
    click_button "Save Picks"
    assert_current_path race_pick_compare_path(username: @user.username, race_id: @race.id)
    assert_selector ".picks-saved-state", text: "editable until"
    assert_nil page.evaluate_script("sessionStorage.getItem(#{@storage_key.to_json})")
    click_link "Edit picks"
    assert_selector ".picks-save-summary", text: "Saved · editable"
    assert_equal drivers(:verstappen).id, draft.first["driver_id"]
  end

  test "top ten is complete and the rest needs explicit opt in" do
    click_button "Randomise rest"
    assert_selector ".picks-counter", text: "10/10"
    assert_equal 10, draft.length
    assert draft.all? { |row| row["source"] == "random" }
    assert_selector ".picks-save-summary", text: "Top 10 ready"
    assert_no_selector ".picks-driver-card:not(:disabled)"
    click_button "Rank the rest (optional)"
    assert_selector ".picks-driver-card:not(:disabled)", count: 12
    click_button "Randomise rest"
    assert_equal 22, draft.length
    assert_selector ".picks-card-cutoff", text: "Optional positions · no points or cards"
    assert_selector ".picks-counter", text: "10/10"
    assert_selector ".picks-save-summary", text: "12 optional"
    click_button "Undo", exact: true
    assert_equal 10, draft.length
    click_button "Save Picks"
    assert_current_path race_pick_compare_path(username: @user.username, race_id: @race.id)
    assert_equal 10, RacePick.find_by!(user: @user, race: @race).picks.length
  end

  test "keyboard picking reordering removal and clear can be undone" do
    find(".picks-driver-card[data-driver-id='#{drivers(:verstappen).id}']").send_keys(:enter)
    pick drivers(:norris)
    find("button[aria-label='Move Lando Norris up']").send_keys(:enter)
    assert_equal drivers(:norris).id, draft.first["driver_id"]
    find("button[aria-label='Remove Lando Norris']").click
    assert_equal 1, draft.length
    click_button "Undo", exact: true
    assert_equal drivers(:norris).id, draft.first["driver_id"]
    click_button "Clear", exact: true
    assert_empty draft
    click_button "Undo", exact: true
    assert_equal 2, draft.length
    click_button "Clear", exact: true
    page.refresh
    assert_empty draft
    assert_button "Save Picks", disabled: true
  end

  test "desktop drag still reorders picks and can be undone" do
    pick drivers(:verstappen)
    pick drivers(:norris)
    pick drivers(:leclerc)
    find(".pick-slot-filled[data-driver-id='#{drivers(:norris).id}'] .pick-slot-name")
      .drag_to(find(".pick-slot-filled[data-driver-id='#{drivers(:verstappen).id}'] .pick-slot-name"))
    assert_selector ".pick-slot-filled:first-child", text: "Lando Norris"
    assert_equal drivers(:norris).id, draft.first["driver_id"]
    assert_equal [1, 2, 3], draft.map { |pick| pick["position"] }
    click_button "Undo", exact: true
    assert_equal drivers(:verstappen).id, draft.first["driver_id"]
  end

  test "invalid drafts and drafts older than saved picks are not restored" do
    page.execute_script("sessionStorage.setItem(#{@storage_key.to_json}, '{broken')")
    page.refresh
    assert_selector ".picks-draft-message", text: "Could not restore"
    pick drivers(:norris)
    RacePick.create!(user: @user, race: @race, picks: [{ driver_id: drivers(:verstappen).id, position: 1, source: "manual" }])
    page.refresh
    assert_selector ".picks-draft-message", text: "outdated draft"
    assert_equal drivers(:verstappen).id, draft.first["driver_id"]
    assert_nil page.evaluate_script("sessionStorage.getItem(#{@storage_key.to_json})")
  end

  test "deadline disables changes and saving without submitting the draft" do
    pick drivers(:norris)
    page.execute_script(<<~JS)
      const element = document.querySelector('[data-controller="race-picks"]');
      const controller = window.Stimulus.getControllerForElementAndIdentifier(element, 'race-picks');
      controller.closesAtValue = new Date(Date.now() - 1000).toISOString();
      controller.checkDeadline();
    JS
    assert_button "Save Picks", disabled: true
    assert_no_selector ".picks-driver-card:not(:disabled)"
    assert_selector ".picks-save-summary", text: "Locked"
    assert_selector ".picks-draft-message", text: "Unsaved changes were not submitted"
    assert_nil page.evaluate_script("sessionStorage.getItem(#{@storage_key.to_json})")
    assert_nil RacePick.find_by(user: @user, race: @race)
  end

  test "guest phone draft survives refresh and signup round trip without claiming it is saved" do
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 956, deviceScaleFactor: 1, mobile: true)
    visit_editor
    pick drivers(:norris)
    page.refresh
    assert_selector ".pick-slot-filled", text: "Lando Norris"
    assert_selector ".picks-save-summary", text: "Unsaved changes"
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 320
    click_button "Sign Up to Save Picks"
    assert_current_path new_user_registration_path
    assert_nil page.evaluate_script("sessionStorage.getItem('f1elo:picks:guest:#{@race.id}')")
    page.go_back
    assert_current_path edit_race_picks_path
    wait_for_stimulus "race-picks", "[data-controller='race-picks']"
    assert_equal drivers(:norris).id, draft.first["driver_id"]
    assert_selector ".picks-save-summary", text: "Sign up to save"
    assert_no_text "Saved · editable"
  end

  test "unavailable browser storage does not prevent an explicit save" do
    page.execute_script("Storage.prototype.setItem = () => { throw new Error('blocked') }")
    pick drivers(:norris)
    assert_selector ".picks-save-summary", text: "keep this page open"
    click_button "Save Picks"
    assert_current_path race_pick_compare_path(username: @user.username, race_id: @race.id)
    assert_equal drivers(:norris).id, RacePick.find_by!(user: @user, race: @race).picks.first["driver_id"]
  end

  private

  def visit_editor
    visit edit_race_picks_path
    wait_for_stimulus "race-picks", "[data-controller='race-picks']"
  end

  def pick(driver)
    find(".picks-driver-card[data-driver-id='#{driver.id}']").click
  end

  def draft
    JSON.parse(find("input[name='picks']", visible: false).value)
  end
end
