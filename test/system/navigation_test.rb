require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  test "signed-in user can reach the tail of the fantasy menu on mobile" do
    page.current_window.resize_to(390, 844)
    sign_in_as users(:codex)

    wait_for_stimulus "navbar", ".navbar"
    page.execute_script("arguments[0].click()", find(".menu-toggle"))
    assert_selector ".navbar.menu-open"
    page.execute_script("arguments[0].click()", find("button[aria-label='More fantasy pages']"))
    page.execute_script(
      "arguments[0].click()",
      find("a[href='#{driver_cards_path(username: users(:codex).username)}']")
    )

    assert_current_path driver_cards_path(username: users(:codex).username)
    assert_text "Driver Cards"
  end

  test "visitor can reach the tail of the history menu on mobile" do
    page.current_window.resize_to(390, 844)
    visit root_path

    wait_for_stimulus "navbar", ".navbar"
    find(".menu-toggle").click
    assert_selector ".navbar.menu-open"
    find(".nav-dropdown-toggle", text: "HISTORY").click
    find("a[href='#{best_pairings_constructors_path}']").click

    assert_current_path best_pairings_constructors_path
    assert_text "Best Teammate Pairings"
  end
end
