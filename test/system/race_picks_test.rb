require "application_system_test_case"

class RacePicksTest < ApplicationSystemTestCase
  setup do
    @race = races(:melbourne_2026)
    @race.update!(date: Date.current + 5.days, time: "14:00:00")
  end

  test "signed-in user builds and saves a race pick" do
    user = users(:codex)
    sign_in_as user

    visit edit_race_picks_path
    wait_for_stimulus "race-picks", "[data-controller='race-picks']"
    page.execute_script("arguments[0].click()", find_button("Randomise rest"))

    assert_selector "[data-race-picks-target='counter']", text: "4/4"
    assert_button "Save Picks", disabled: false
    page.execute_script("arguments[0].click()", find_button("Save Picks"))

    assert_current_path race_pick_compare_path(username: user.username, race_id: @race.id)
    assert_text "How you compare"
  end

  test "guest picks survive account creation" do
    visit edit_race_picks_path
    wait_for_stimulus "race-picks", "[data-controller='race-picks']"
    find("[data-driver-id='#{drivers(:norris).id}']").click
    click_button "Sign Up to Save Picks"

    fill_in "Username", with: "pickstarter"
    fill_in "Email", with: "pickstarter@example.com"
    fill_in "Password", with: "password123"
    check "user_terms_accepted"
    click_button "Join F1 Elo"

    assert_current_path fantasy_overview_path("pickstarter")
    assert_text "Your picks for #{@race.circuit.name} have been saved!"
  end
end
