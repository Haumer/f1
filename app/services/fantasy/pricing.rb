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

    def self.demand_multiplier(net_demand)
      if net_demand >= 0
        1 + DEMAND_RATE * (net_demand**DEMAND_EXPONENT)
      else
        [1 - DEMAND_RATE * (net_demand.abs**DEMAND_EXPONENT), DEMAND_FLOOR].max
      end
    end

    # Stock price includes demand premium/discount
    def self.stock_price_for(driver, season)
      base = (driver.elo_v2 || ROOKIE_PRICE) / FantasyStockPortfolio::PRICE_DIVISOR
      sd = SeasonDriver.find_by(driver_id: driver.id, season_id: season.id)
      base * demand_multiplier(sd&.net_demand || 0)
    end
  end
end
