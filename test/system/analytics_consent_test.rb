require "application_system_test_case"

class AnalyticsConsentTest < ApplicationSystemTestCase
  test "visitor can decline optional Google Analytics before it loads" do
    original_id = ENV["GOOGLE_ANALYTICS_ID"]
    ENV["GOOGLE_ANALYTICS_ID"] = "G-TEST123"

    visit root_path
    page.execute_script("window.localStorage.removeItem('f1elo.analytics-consent')")
    refresh
    wait_for_stimulus "analytics-consent", "body"

    assert_selector ".analytics-consent", visible: true
    assert_no_selector "script[src*='googletagmanager.com/gtag/js']", visible: :all

    click_button "No thanks"

    assert_no_selector ".analytics-consent", visible: true
    assert_equal "denied", page.evaluate_script("window.localStorage.getItem('f1elo.analytics-consent')")

    refresh
    wait_for_stimulus "analytics-consent", "body"
    assert_no_selector ".analytics-consent", visible: true
    assert_no_selector "script[src*='googletagmanager.com/gtag/js']", visible: :all
  ensure
    original_id.nil? ? ENV.delete("GOOGLE_ANALYTICS_ID") : ENV["GOOGLE_ANALYTICS_ID"] = original_id
  end
end
