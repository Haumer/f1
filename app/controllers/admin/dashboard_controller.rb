module Admin
  class DashboardController < BaseController
    def index
      @total_drivers = Driver.count
      @active_drivers = Driver.active.count
      @total_races = Race.count
      @total_seasons = Season.count
      @elo_version = Setting.elo_version
      @v2_populated = Driver.where.not(elo_v2: nil).exists?
      @alerts = AdminAlert.unresolved.recent.limit(10)
    end
  end
end
