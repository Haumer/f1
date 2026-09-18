require "test_helper"

class HeadToHeadControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "show renders a matchup for a guest" do
    get head_to_head_path
    assert_response :success
    assert_select ".h2h-cards"
    assert_select "form.h2h-card-form", minimum: 2
  end

  test "pick records a match and advances the round" do
    get head_to_head_path
    # Extract the two driver ids from the rendered forms.
    winner = css_select("form.h2h-card-form input[name='winner_driver_id']").first["value"].to_i
    loser  = css_select("form.h2h-card-form input[name='loser_driver_id']").first["value"].to_i

    assert_difference "DriverPreferenceMatch.count", 1 do
      post pick_head_to_head_path, params: { winner_driver_id: winner, loser_driver_id: loser }
    end

    session = DriverPreferenceSession.order(:id).last
    assert_equal 1, session.rounds_played
    assert_equal winner, session.champion_driver_id
  end

  test "results page renders a crowd ranking" do
    get head_to_head_results_path
    assert_response :success
  end

  test "finish page redirects when no session token is set" do
    get finish_head_to_head_path
    assert_redirected_to head_to_head_path
  end

  test "start is idempotent per race — no duplicate sessions once one exists" do
    get head_to_head_path
    initial = DriverPreferenceSession.count
    post start_head_to_head_path
    assert_equal initial, DriverPreferenceSession.count, "start should not spawn a second session for the same race"
    assert_redirected_to head_to_head_path
  end

  test "finished ranking links the owner to their chosen driver's market row" do
    sign_in users(:codex)
    races(:melbourne_2026).update!(date: 2.days.from_now.to_date)
    finish_ranking(drivers(:leclerc))
    portfolio = fantasy_stock_portfolios(:codex_stock_2026)
    expected = market_fantasy_stock_portfolio_path(portfolio, driver: drivers(:leclerc).id, anchor: "driver-#{drivers(:leclerc).id}")
    assert_select ".h2h-buy-prompt a[href=?][data-turbo-frame='_top']", expected, text: "Buy Leclerc shares"
    assert_select ".h2h-buy-prompt", text: /Game credits only. No real money./
  end

  test "closed market offers browsing rather than an unavailable purchase" do
    sign_in users(:codex)
    finish_ranking(drivers(:leclerc))
    assert_select ".h2h-buy-prompt", text: /Market closed/
    assert_select ".h2h-buy-prompt a", text: "Browse drivers"
    assert_select ".h2h-buy-prompt a", text: /Buy .* shares/, count: 0
  end

  test "insufficient credits and an opposing holding do not promise buying" do
    sign_in users(:codex)
    races(:melbourne_2026).update!(date: 2.days.from_now.to_date)
    finish_ranking(drivers(:norris)) # Existing short position.
    assert_select ".h2h-buy-prompt a", text: "Browse drivers"
    fantasy_portfolios(:codex_2026).update!(cash: 337.5)
    finish_ranking(drivers(:leclerc))
    assert_select ".h2h-buy-prompt a", text: "Browse drivers"
  end

  test "position limit allows adding owned shares but not a new driver" do
    sign_in users(:codex)
    races(:melbourne_2026).update!(date: 2.days.from_now.to_date)
    portfolio = fantasy_stock_portfolios(:codex_stock_2026)
    10.times do |i|
      driver = Driver.create!(driver_ref: "limit_#{i}", surname: "Limit #{i}", elo_v2: 2000)
      portfolio.holdings.create!(driver: driver, direction: "long", quantity: 1, entry_price: 200, active: true, opened_race: races(:bahrain_2026))
    end
    finish_ranking(drivers(:leclerc))
    assert_select ".h2h-buy-prompt a", text: "Browse drivers"
    finish_ranking(drivers(:verstappen))
    assert_select ".h2h-buy-prompt a", text: "Buy Verstappen shares"
  end

  test "guest historical and unavailable-driver rankings do not suggest an invalid purchase" do
    finish_ranking(drivers(:leclerc))
    assert_select ".h2h-buy-prompt", count: 0
    assert_select ".h2h-signup-card"
    sign_in users(:codex)
    finish_ranking(drivers(:leclerc), year: 2025)
    assert_select ".h2h-buy-prompt", count: 0
    seasons(:season_2026).season_drivers.where(driver: drivers(:leclerc)).delete_all
    finish_ranking(drivers(:leclerc))
    assert_select ".h2h-buy-prompt a", text: "Browse drivers"
    assert_select ".h2h-buy-prompt a[href*='driver=']", count: 0
  end

  private

  def finish_ranking(driver, year: 2026)
    get head_to_head_path(year: year)
    record = DriverPreferenceSession.where(year: year).order(:id).last
    record.update!(champion_driver: driver, rounds_played: 12, finished_at: Time.current)
    get finish_head_to_head_path(year: year)
    assert_response :success
  end
end
