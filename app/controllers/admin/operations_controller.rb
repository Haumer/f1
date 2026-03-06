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
