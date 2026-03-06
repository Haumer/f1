module Fantasy
  module Pricing
    # Rookies start at the same Elo the rating system assigns on first race.
    ROOKIE_PRICE = EloRatingV2::STARTING_ELO

    def self.price_for(driver, _season = nil)
      driver.elo_v2 || ROOKIE_PRICE
    end
  end
end
