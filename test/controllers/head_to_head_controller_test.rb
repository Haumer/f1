require "test_helper"

class HeadToHeadControllerTest < ActionDispatch::IntegrationTest
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
end
