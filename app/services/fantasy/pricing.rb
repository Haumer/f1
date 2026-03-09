module Fantasy
  module Pricing
    # Rookies start at the same Elo the rating system assigns on first race.
    ROOKIE_PRICE = EloRatingV2::STARTING_ELO

    # Demand pricing: slightly accelerating curve (^1.3)
    # Calibrated so 100 net shares = 0.5% premium
    DEMAND_EXPONENT = 1.3
    DEMAND_RATE = 0.005 / (100**DEMAND_EXPONENT) # ≈ 0.00001256
    DEMAND_FLOOR = 0.01 # price can't drop below 1% of base

    def self.price_for(driver, _season = nil)
      driver.elo_v2 || ROOKIE_PRICE
    end

    # Stock price includes demand premium/discount
    def self.stock_price_for(driver, season)
      base = (driver.elo_v2 || ROOKIE_PRICE) / FantasyStockPortfolio::PRICE_DIVISOR
      sd = SeasonDriver.find_by(driver_id: driver.id, season_id: season.id)
      net = sd&.net_demand || 0
      multiplier = if net >= 0
        1 + DEMAND_RATE * (net**DEMAND_EXPONENT)
      else
        [1 - DEMAND_RATE * (net.abs**DEMAND_EXPONENT), DEMAND_FLOOR].max
      end
      base * multiplier
    end
  end
end
