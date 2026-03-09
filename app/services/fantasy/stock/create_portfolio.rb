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

        # Stock portfolio has no cash — capital is added to the roster wallet
        portfolio = FantasyStockPortfolio.create!(
          user: @user,
          season: @season,
          cash: 0,
          starting_capital: capital
        )

        # Add stock capital to the unified wallet (roster portfolio)
        roster = @user.fantasy_portfolio_for(@season)
        if roster
          roster.with_lock do
            roster.update!(cash: roster.cash + capital)
          end
        end

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
