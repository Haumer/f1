require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  setup do
    page.current_window.resize_to(1400, 1400)
  end

  private

  def sign_in_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign In"
    assert_text "Signed in successfully.", wait: 5
    if has_css?(".flash-dismiss", wait: 0)
      page.execute_script("arguments[0].click()", find(".flash-dismiss"))
      assert_no_selector ".flash"
    end
  end

  def wait_for_stimulus(identifier, selector)
    Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
      page.evaluate_script(<<~JS)
        (() => {
          const element = document.querySelector(#{selector.to_json})
          return Boolean(element && window.Stimulus?.getControllerForElementAndIdentifier(element, #{identifier.to_json}))
        })()
      JS
    end
  end
end
