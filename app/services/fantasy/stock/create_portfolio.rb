module Fantasy
  module Stock
    class CreatePortfolio
      def initialize(user:, season:)
        @user = user
        @season = season
      end

      def call
        return { error: "You already have a stock portfolio for this season" } if @user.fantasy_stock_portfolio_for(@season)

        roster = @user.fantasy_portfolio_for(@season)
        return { error: "You need a roster portfolio first" } unless roster

        # Stock portfolio has no starting capital — it's already in roster's starting_capital
        portfolio = FantasyStockPortfolio.create!(
          user: @user,
          season: @season,
          cash: 0,
          starting_capital: 0
        )

        # Unlock the second half of starting capital
        unlock_amount = (roster.starting_capital / 2.0).round(1)
        roster.with_lock do
          roster.update!(cash: roster.cash + unlock_amount)
        end

        roster.transactions.create!(
          kind: "starting_capital",
          amount: unlock_amount,
          note: "Stock market unlocked"
        )

        { portfolio: portfolio }
      end
    end
  end
end
