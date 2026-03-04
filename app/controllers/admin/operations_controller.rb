module Admin
  class OperationsController < BaseController
    def index
    end

    def create
      case params[:operation]
      when "sync_season"
        year = params[:year].presence || Date.current.year
        season = SeasonSync.new(year: year).sync
        if season
          redirect_to admin_operations_path, notice: "Season #{year} synced. #{season.races.count} races."
        else
          redirect_to admin_operations_path, alert: "Failed to sync season #{year}."
        end
      when "elo_v2_simulate"
        result = EloRatingV2.simulate_all!
        redirect_to admin_operations_path, notice: "Elo V2 simulated. #{result[:drivers_updated]} drivers, #{result[:race_results_updated]} race results updated."
      when "constructor_elo"
        ConstructorElo.recalculate_all!
        redirect_to admin_operations_path, notice: "Constructor Elo recalculated."
      when "constructor_elo_v2"
        result = ConstructorEloV2.simulate_all!
        redirect_to admin_operations_path, notice: "Constructor Elo V2 simulated. #{result[:constructors_updated]} constructors, #{result[:race_results_updated]} race results updated."
      when "backfill_careers"
        count = 0
        Driver.find_each do |driver|
          UpdateDriverCareer.new(driver: driver).update
          count += 1
        end
        redirect_to admin_operations_path, notice: "Career stats updated for #{count} drivers."
      when "update_active_drivers"
        UpdateActiveDrivers.update_season
        redirect_to admin_operations_path, notice: "Active drivers updated."
      else
        redirect_to admin_operations_path, alert: "Unknown operation."
      end
    end
  end
end
