module Fantasy
  class Leaderboard
    def initialize(season:)
      @season = season
    end

    def call
      portfolios = FantasyPortfolio
        .where(season: @season)
        .includes(:user)
        .to_a
      return [] if portfolios.empty?

      stock_by_user = stock_portfolios_by_user(portfolios)
      prices = prices_for(stock_by_user.values)

      portfolios.map do |portfolio|
        stock_portfolio = stock_by_user[portfolio.user_id]
        value = portfolio.cash + (stock_portfolio&.positions_value(prices) || 0)

        {
          portfolio: portfolio,
          value: value,
          net: (value - Fantasy::CreatePortfolio::STARTING_CAPITAL).round(2),
          stock_portfolio_id: stock_portfolio&.id
        }
      end.sort_by { |entry| -entry[:net] }
    end

    private

    def stock_portfolios_by_user(portfolios)
      FantasyStockPortfolio
        .where(user_id: portfolios.map(&:user_id), season: @season)
        .includes(:holdings)
        .index_by(&:user_id)
    end

    def prices_for(stock_portfolios)
      driver_ids = stock_portfolios.flat_map do |portfolio|
        portfolio.holdings.select(&:active).map(&:driver_id)
      end.uniq

      Fantasy::Pricing.prices_for_season(driver_ids, @season)
    end
  end
end
