module Admin
  class OperationsController < BaseController
    def index
    end

    def create
      case params[:operation]
      when "sync_season"
        year = params[:year].presence || Date.current.year
        PostRaceSyncJob.perform_later(year: year.to_i)
        redirect_to admin_operations_path, notice: "Season #{year} sync job enqueued."
      when "elo_v2_simulate"
        EloSimulateJob.perform_later
        redirect_to admin_operations_path, notice: "Elo V2 simulation job enqueued."
      when "constructor_elo_v2"
        EloSimulateJob.perform_later
        redirect_to admin_operations_path, notice: "Elo simulation job enqueued (includes constructor Elo)."
      when "backfill_careers"
        BackfillCareersJob.perform_later
        redirect_to admin_operations_path, notice: "Career stats backfill job enqueued."
      when "update_active_drivers"
        UpdateActiveDrivers.update_season
        redirect_to admin_operations_path, notice: "Active drivers updated."
      when "compute_badges"
        ComputeBadgesJob.perform_later
        redirect_to admin_operations_path, notice: "Badge computation job enqueued."
      when "full_data_sync"
        start_year = (params[:start_year].presence || 1950).to_i
        end_year = (params[:end_year].presence || Date.current.year).to_i
        FullDataSyncJob.perform_later(start_year: start_year, end_year: end_year)
        redirect_to admin_operations_path, notice: "Full data sync job enqueued (#{start_year}-#{end_year}). This will take several minutes."
      when "fetch_wikipedia_images"
        count = FetchWikipediaImages.fetch_all
        redirect_to admin_operations_path, notice: "Fetched #{count} Wikipedia images."
      when "recalc_net_demand"
        season = Season.sorted_by_year.first
        # Reset all to 0 first
        SeasonDriver.where(season: season).update_all(net_demand: 0)
        # Recalculate from active holdings
        holdings = FantasyStockHolding.joins(:fantasy_stock_portfolio)
          .where(fantasy_stock_portfolios: { season_id: season.id }, active: true)
        count = 0
        holdings.group_by(&:driver_id).each do |driver_id, hs|
          longs = hs.select(&:long?).sum(&:quantity)
          shorts = hs.select(&:short?).sum(&:quantity)
          net = longs - shorts
          sd = SeasonDriver.find_by(driver_id: driver_id, season_id: season.id)
          next unless sd
          sd.update!(net_demand: net)
          count += 1
        end
        redirect_to admin_operations_path, notice: "Recalculated net_demand for #{count} drivers."

      when "resnap_portfolios"
        race = Race.find(params[:race_id])
        Fantasy::SnapshotPortfolios.new(race: race).call
        Fantasy::Stock::SettleRace.new(race: race).call
        redirect_to admin_operations_path, notice: "Re-snapshotted portfolios for #{race.circuit.name} (R#{race.round})."

      when "verify_cash"
        season = Season.sorted_by_year.first
        issues = []
        FantasyPortfolio.where(season: season).includes(:user).each do |p|
          sp = FantasyStockPortfolio.find_by(user_id: p.user_id, season_id: season.id)
          next unless sp
          # Total capital given = roster starting + stock starting
          total_starting = p.starting_capital + sp.starting_capital
          # Total accounted = cash + roster drivers + stock positions + fees/dividends
          roster_value = p.active_roster_entries.includes(:driver).sum { |e| Fantasy::Pricing.price_for(e.driver, season) }
          stock_value = sp.positions_value
          total_accounted = p.cash + roster_value + stock_value
          diff = (total_accounted - total_starting).round(1)
          if diff.abs > 50
            issues << "#{p.user.username}: starting=#{total_starting.round(0)} current=#{total_accounted.round(0)} diff=#{diff}"
          end
        end
        msg = issues.any? ? "Issues found: #{issues.join('; ')}" : "All portfolios consistent."
        redirect_to admin_operations_path, notice: msg

      when "fix_collateral"
        season = Season.sorted_by_year.first
        count = 0
        FantasyStockHolding.joins(:fantasy_stock_portfolio)
          .where(fantasy_stock_portfolios: { season_id: season.id }, active: true, direction: "short")
          .includes(:driver, :fantasy_stock_portfolio).each do |h|
          price = h.fantasy_stock_portfolio.share_price(h.driver)
          correct = price * h.quantity * FantasyStockPortfolio::COLLATERAL_RATIO
          next if (h.collateral - correct).abs < 0.01
          h.update!(collateral: correct)
          count += 1
        end
        redirect_to admin_operations_path, notice: "Fixed collateral for #{count} short positions (#{(FantasyStockPortfolio::COLLATERAL_RATIO * 100).round(0)}% ratio)."

      when "recapitalize_fantasy"
        season = Season.find_by(year: Date.current.year.to_s) || Season.sorted_by_year.first
        avg_elo = Driver.where.not(elo_v2: nil)
                        .joins(:season_drivers)
                        .where(season_drivers: { season_id: season.id })
                        .average(:elo_v2)
        # Fall back to all active drivers if no season_drivers exist yet
        avg_elo ||= Driver.active.where.not(elo_v2: nil).average(:elo_v2) || 2200
        new_capital = (avg_elo * Fantasy::CreatePortfolio::CAPITAL_MULTIPLIER).round(1)
        updated = FantasyPortfolio.where(season: season).update_all(cash: new_capital, starting_capital: new_capital)
        redirect_to admin_operations_path, notice: "Recapitalized #{updated} fantasy portfolio(s) with #{new_capital} credits."
      else
        redirect_to admin_operations_path, alert: "Unknown operation."
      end
    end
  end
end
