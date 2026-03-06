module Fantasy
  class Leaderboard
    def initialize(season:)
      @season = season
    end

    def call
      portfolios = FantasyPortfolio
        .where(season: @season)
        .includes(:user, :snapshots, roster_entries: :driver)
        .to_a

      portfolios
        .map { |p| { portfolio: p, value: p.portfolio_value } }
        .sort_by { |entry| -entry[:value] }
    end
  end
end
