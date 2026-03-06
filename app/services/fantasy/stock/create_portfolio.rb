module Fantasy
  module Stock
    class CreatePortfolio
      def initialize(user:, season:)
        @user = user
        @season = season
      end

      def call
        return { error: "You already have a stock portfolio for this season" } if @user.fantasy_stock_portfolio_for(@season)

        capital = compute_starting_capital
        portfolio = FantasyStockPortfolio.create!(
          user: @user,
          season: @season,
          cash: capital,
          starting_capital: capital
        )

        { portfolio: portfolio }
      end

      private

      def compute_starting_capital
        avg_elo = Driver.where.not(elo_v2: nil)
                        .joins(:season_drivers)
                        .where(season_drivers: { season_id: @season.id })
                        .average(:elo_v2) || 0
        (avg_elo * FantasyStockPortfolio::CAPITAL_MULTIPLIER).round(1)
      end
    end
  end
end
