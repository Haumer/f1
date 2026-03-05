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
      else
        redirect_to admin_operations_path, alert: "Unknown operation."
      end
    end
  end
end
