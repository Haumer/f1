module Fantasy
  class CreatePortfolio
    STARTING_CAPITAL = 9450.0  # Fixed starting capital for all users

    def initialize(user:, season:)
      @user = user
      @season = season
    end

    def call
      return { error: "You already have a portfolio for this season" } if @user.fantasy_portfolio_for(@season)

      portfolio = FantasyPortfolio.create!(
        user: @user,
        season: @season,
        cash: STARTING_CAPITAL,
        starting_capital: STARTING_CAPITAL
      )

      portfolio.transactions.create!(
        kind: "starting_capital",
        amount: STARTING_CAPITAL,
        note: "Starting capital"
      )

      { portfolio: portfolio }
    end

    private
  end
end
