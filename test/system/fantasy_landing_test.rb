require "application_system_test_case"

class FantasyLandingTest < ApplicationSystemTestCase
  test "visitor can understand and enter the fantasy game" do
    visit fantasy_home_path

    assert_text "Back your read"
    assert_text "Three decisions that matter"
    assert_link "Play free", href: new_user_registration_path, minimum: 1
    assert_selector ".fantasy-landing-hero .fantasy-btn", minimum: 2
    assert_selector ".fantasy-console-row", minimum: 1
  end

  test "fantasy landing remains usable on a phone" do
    page.current_window.resize_to(390, 844)
    visit fantasy_home_path

    assert_selector ".fantasy-landing-hero"
    assert_link "Play free", href: new_user_registration_path, minimum: 1
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"),
                    :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end
end
