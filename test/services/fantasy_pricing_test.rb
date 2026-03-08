require "test_helper"

class FantasyPricingTest < ActiveSupport::TestCase
  test "price_for returns driver elo_v2" do
    driver = drivers(:verstappen)
    price = Fantasy::Pricing.price_for(driver)
    assert_in_delta driver.elo_v2, price, 0.01
  end

  test "price_for returns ROOKIE_PRICE when driver has no elo" do
    driver = Driver.new(surname: "Rookie", driver_ref: "rookie")
    price = Fantasy::Pricing.price_for(driver)
    assert_equal EloRatingV2::STARTING_ELO, price
  end

  test "ROOKIE_PRICE equals STARTING_ELO" do
    assert_equal EloRatingV2::STARTING_ELO, Fantasy::Pricing::ROOKIE_PRICE
  end
end
