require "test_helper"

class DriverCardsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user  = users(:codex)
    @other = users(:latejoin)
  end

  def card_attrs(overrides = {})
    {
      user: @user, driver: drivers(:verstappen), race: races(:bahrain_2026),
      predicted_position: 1, actual_position: 1, tier: "gold",
      snapshot_wins: 60, snapshot_podiums: 110, snapshot_wdc: 3,
      snapshot_elo: 2400.0, earned_at: Time.current
    }.merge(overrides)
  end

  # ───── /cards redirect ─────

  test "/cards redirects guests to sign in" do
    get "/cards"
    assert_redirected_to new_user_session_path
  end

  test "/cards redirects signed-in user to their own collection" do
    sign_in @user
    get "/cards"
    assert_redirected_to "/fantasy/u/#{@user.username}/cards"
  end

  # ───── Index ─────

  test "index is public — guests can view a user's collection" do
    get driver_cards_path(username: @user.username)
    assert_response :success
    assert_select ".dc-empty"
  end

  test "index renders empty-state for a user with no cards" do
    get driver_cards_path(username: @user.username)
    assert_response :success
    assert_select ".dc-empty"
  end

  test "index renders grid when cards exist (signed-in owner)" do
    sign_in @user
    DriverCard.create!(card_attrs)
    get driver_cards_path(username: @user.username)
    assert_response :success
    assert_select ".dc-card.tier-gold"
    assert_select ".dc-stat .val", text: "1", count: 3
  end

  test "index 404s for unknown username" do
    get driver_cards_path(username: "ghost-user-9999")
    assert_response :not_found
  end

  # ───── Show ─────

  test "show renders a single card publicly" do
    card = DriverCard.create!(card_attrs(tier: "platinum"))
    get driver_card_path(username: @user.username, id: card.id)
    assert_response :success
    assert_select ".dc-card.tier-platinum"
  end

  test "show 404s when card belongs to a different user than the URL username" do
    sign_in @user
    other_card = DriverCard.create!(card_attrs(user: @other))
    # Querying under @user's URL for a card belonging to @other → not found.
    get driver_card_path(username: @user.username, id: other_card.id)
    assert_response :not_found
  end

  # ───── Combine ─────

  def seed_combinable!(tier:, user: @user, driver: drivers(:verstappen))
    [races(:bahrain_2025), races(:melbourne_2025), races(:bahrain_2026)].each_with_index do |race, i|
      DriverCard.create!(card_attrs(
        user: user, driver: driver, race: race, tier: tier,
        earned_at: (3 - i).days.ago
      ))
    end
  end

  test "owner can combine their own cards" do
    sign_in @user
    driver = drivers(:verstappen)
    seed_combinable!(tier: "bronze")

    assert_difference -> { DriverCard.where(user: @user, driver: driver).count }, -2 do
      post combine_driver_cards_path(username: @user.username), params: { driver_id: driver.id, tier: "bronze" }
    end
    assert_response :redirect
    assert_equal 1, DriverCard.where(user: @user, driver: driver, tier: "silver").count
  end

  test "non-owner cannot combine someone else's cards" do
    sign_in @other
    driver = drivers(:verstappen)
    seed_combinable!(tier: "bronze") # belongs to @user, not @other

    assert_no_difference -> { DriverCard.count } do
      post combine_driver_cards_path(username: @user.username), params: { driver_id: driver.id, tier: "bronze" }
    end
    assert_response :redirect
    assert_match(/can only combine your own/i, flash[:alert])
  end

  test "guest cannot combine" do
    driver = drivers(:verstappen)
    seed_combinable!(tier: "bronze")

    assert_no_difference -> { DriverCard.count } do
      post combine_driver_cards_path(username: @user.username), params: { driver_id: driver.id, tier: "bronze" }
    end
    assert_redirected_to new_user_session_path
  end

  test "combine surfaces error when fewer than 3 cards" do
    sign_in @user
    driver = drivers(:verstappen)
    DriverCard.create!(card_attrs(tier: "bronze"))

    assert_no_difference -> { DriverCard.count } do
      post combine_driver_cards_path(username: @user.username), params: { driver_id: driver.id, tier: "bronze" }
    end
    assert_response :redirect
    assert_match(/need 3 bronze cards/, flash[:alert])
  end

  test "combine refuses legendary" do
    sign_in @user
    driver = drivers(:verstappen)
    seed_combinable!(tier: "legendary")

    assert_no_difference -> { DriverCard.count } do
      post combine_driver_cards_path(username: @user.username), params: { driver_id: driver.id, tier: "legendary" }
    end
    assert_match(/legendary can't/i, flash[:alert])
  end
end
