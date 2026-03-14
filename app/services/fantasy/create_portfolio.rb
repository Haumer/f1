module Fantasy
  class CreatePortfolio
    STARTING_CAPITAL = 9450.0  # Fixed starting capital for all users

    def initialize(user:, season:)
      @user = user
      @season = season
    end

    def call
      return { error: "You already have a portfolio for this season" } if @user.fantasy_portfolio_for(@season)

      starting_capital = STARTING_CAPITAL
      roster_cash = (starting_capital / 2.0).round(1)
      portfolio = FantasyPortfolio.create!(
        user: @user,
        season: @season,
        cash: roster_cash,
        starting_capital: starting_capital
      )

      portfolio.transactions.create!(
        kind: "starting_capital",
        amount: roster_cash,
        note: "Starting capital (roster)"
      )

      { portfolio: portfolio }
    end

    private
  end
end
