module Fantasy
  module Pricing
    # Rookies start at the same Elo the rating system assigns on first race.
    ROOKIE_PRICE = EloRatingV2::STARTING_ELO

    DEMAND_RATE = 0.0005 # 0.05% per net share

    def self.price_for(driver, _season = nil)
      driver.elo_v2 || ROOKIE_PRICE
    end

    # Stock price includes demand premium/discount
    def self.stock_price_for(driver, season)
      base = (driver.elo_v2 || ROOKIE_PRICE) / FantasyStockPortfolio::PRICE_DIVISOR
      sd = SeasonDriver.find_by(driver_id: driver.id, season_id: season.id)
      net = sd&.net_demand || 0
      base * (1 + net * DEMAND_RATE)
    end
  end
end
