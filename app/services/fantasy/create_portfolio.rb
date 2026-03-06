module Fantasy
  class CreatePortfolio
    CAPITAL_MULTIPLIER = 2.2

    def initialize(user:, season:)
      @user = user
      @season = season
    end

    def call
      return { error: "You already have a portfolio for this season" } if @user.fantasy_portfolio_for(@season)

      starting_capital = compute_starting_capital
      portfolio = FantasyPortfolio.create!(
        user: @user,
        season: @season,
        cash: starting_capital,
        starting_capital: starting_capital
      )

      { portfolio: portfolio }
    end

    private

    def compute_starting_capital
      avg_elo = Driver.where.not(elo_v2: nil)
                      .joins(:season_drivers)
                      .where(season_drivers: { season_id: @season.id })
                      .average(:elo_v2) || 0
      (avg_elo * CAPITAL_MULTIPLIER).round(1)
    end
  end
end
