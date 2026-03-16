module Fantasy
  class Leaderboard
    def initialize(season:)
      @season = season
    end

    def call
      portfolios = FantasyPortfolio
        .where(season: @season)
        .includes(:user, :snapshots)
        .to_a

      portfolios
        .map { |p| { portfolio: p, value: p.portfolio_value, net: p.total_return } }
        .sort_by { |entry| -entry[:net] }
    end
  end
end
