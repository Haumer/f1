module Fantasy
  module Stock
    class CreatePortfolio
      def initialize(user:, season:)
        @user = user
        @season = season
      end

      def call
        return { error: "You already have a stock portfolio for this season" } if @user.fantasy_stock_portfolio_for(@season)

        portfolio = FantasyStockPortfolio.create!(
          user: @user,
          season: @season,
          cash: 0,
          starting_capital: 0
        )

        { portfolio: portfolio }
      end
    end
  end
end
