module Fantasy
  class SnapshotPortfolios
    def initialize(race:)
      @race = race
    end

    def call
      portfolios = FantasyPortfolio.where(season: @race.season)
                     .includes(:user, roster_entries: :driver)
      stock_portfolios = FantasyStockPortfolio.where(season: @race.season)
                           .includes(holdings: :driver)
                           .index_by(&:user_id)

      portfolios_by_id = portfolios.index_by(&:id)

      snapshots = portfolios.map do |portfolio|
        sp = stock_portfolios[portfolio.user_id]
        # Total value = roster portfolio_value (cash + drivers) + stock positions
        value = portfolio.portfolio_value + (sp&.positions_value || 0)
        { fantasy_portfolio_id: portfolio.id, race_id: @race.id, value: value, cash: portfolio.cash }
      end

      # Rank by total return (value - capital, includes dividends/fees)
      ranked = snapshots.sort_by do |s|
        p = portfolios_by_id[s[:fantasy_portfolio_id]]
        -p.total_return
      end
      ranked.each_with_index { |s, i| s[:rank] = i + 1 }

      # Insert snapshots — skip if already snapped for this race
      # (don't overwrite: later trades would corrupt historical values)
      ranked.each do |attrs|
        next if FantasySnapshot.exists?(
          fantasy_portfolio_id: attrs[:fantasy_portfolio_id],
          race_id: attrs[:race_id]
        )
        FantasySnapshot.create!(
          fantasy_portfolio_id: attrs[:fantasy_portfolio_id],
          race_id: attrs[:race_id],
          value: attrs[:value],
          cash: attrs[:cash],
          rank: attrs[:rank]
        )
      end

      # Also snapshot stock portfolios — but only if SettleRace hasn't already
      # (SettleRace creates snapshots after paying dividends/fees, so don't overwrite)
      FantasyStockPortfolio.where(season: @race.season)
        .includes(holdings: :driver).each do |sp|
        next if sp.snapshots.exists?(race: @race)
        FantasyStockSnapshot.create!(
          fantasy_stock_portfolio: sp,
          race: @race,
          value: sp.positions_value,
          cash: 0
        )
      end

      ranked.size
    end
  end
end
