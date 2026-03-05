module Fantasy
  class SnapshotPortfolios
    def initialize(race:)
      @race = race
    end

    def call
      portfolios = FantasyPortfolio.where(season: @race.season)
                     .includes(roster_entries: :driver)

      snapshots = portfolios.map do |portfolio|
        value = portfolio.portfolio_value
        { fantasy_portfolio_id: portfolio.id, race_id: @race.id, value: value, cash: portfolio.cash }
      end

      # Rank by value
      ranked = snapshots.sort_by { |s| -s[:value] }
      ranked.each_with_index { |s, i| s[:rank] = i + 1 }

      # Upsert all snapshots
      ranked.each do |attrs|
        FantasySnapshot.find_or_initialize_by(
          fantasy_portfolio_id: attrs[:fantasy_portfolio_id],
          race_id: attrs[:race_id]
        ).update!(value: attrs[:value], cash: attrs[:cash], rank: attrs[:rank])
      end

      ranked.size
    end
  end
end
