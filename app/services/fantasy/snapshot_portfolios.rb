module Fantasy
  class SnapshotPortfolios
    def initialize(race:)
      @race = race
    end

    def call
      # Build historical Elo map from race results — this is the Elo as of THIS race
      elo_map = RaceResult.where(race: @race).pluck(:driver_id, :new_elo_v2).to_h
      season_drivers = SeasonDriver.where(season_id: @race.season_id).index_by(&:driver_id)

      portfolios = FantasyPortfolio.where(season: @race.season).includes(:user)
      stock_portfolios = FantasyStockPortfolio.where(season: @race.season)
                           .includes(holdings: :driver)
                           .index_by(&:user_id)

      portfolios_by_id = portfolios.index_by(&:id)

      snapshots = portfolios.map do |portfolio|
        # Portfolio value = cash + stock positions (using historical Elo)
        sp = stock_portfolios[portfolio.user_id]
        stock_value = if sp
          compute_positions_value(sp, elo_map, season_drivers)
        else
          0
        end

        value = portfolio.cash + stock_value
        { fantasy_portfolio_id: portfolio.id, race_id: @race.id, value: value, cash: portfolio.cash }
      end

      # Rank by total return (value - capital, includes dividends/fees)
      ranked = snapshots.sort_by do |s|
        p = portfolios_by_id[s[:fantasy_portfolio_id]]
        -p.total_return
      end
      ranked.each_with_index { |s, i| s[:rank] = i + 1 }

      # Upsert snapshots so re-running always produces correct values
      ranked.each do |attrs|
        FantasySnapshot.find_or_initialize_by(
          fantasy_portfolio_id: attrs[:fantasy_portfolio_id],
          race_id: attrs[:race_id]
        ).update!(
          value: attrs[:value],
          cash: attrs[:cash],
          rank: attrs[:rank]
        )
      end

      # Also snapshot stock portfolios — upsert so re-running works
      # (SettleRace may have already created these with post-dividend values)
      FantasyStockPortfolio.where(season: @race.season)
        .includes(holdings: :driver).each do |sp|
        next if sp.snapshots.exists?(race: @race)
        stock_value = compute_positions_value(sp, elo_map, season_drivers)
        FantasyStockSnapshot.create!(
          fantasy_stock_portfolio: sp,
          race: @race,
          value: stock_value,
          cash: 0
        )
      end

      ranked.size
    end

    private

    def compute_positions_value(portfolio, elo_map, season_drivers)
      active = portfolio.holdings.loaded? ? portfolio.holdings.select(&:active) : portfolio.active_holdings.includes(:driver).to_a

      longs_value = active.select { |h| h.direction == "long" }.sum do |h|
        elo = elo_map[h.driver_id] || h.driver.elo_v2
        net_demand = season_drivers[h.driver_id]&.net_demand || 0
        Fantasy::Pricing.stock_price_for_elo(elo, net_demand) * h.quantity
      end

      shorts_pnl = active.select { |h| h.direction == "short" }.sum do |h|
        elo = elo_map[h.driver_id] || h.driver.elo_v2
        net_demand = season_drivers[h.driver_id]&.net_demand || 0
        (h.entry_price - Fantasy::Pricing.stock_price_for_elo(elo, net_demand)) * h.quantity
      end

      longs_value + shorts_pnl
    end
  end
end
