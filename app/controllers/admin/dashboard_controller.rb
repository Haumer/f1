module Admin
  class DashboardController < BaseController
    def index
      @total_drivers = Driver.count
      @active_drivers = Driver.active.count
      @total_races = Race.count
      @total_seasons = Season.count
      @v2_populated = Driver.where.not(elo_v2: nil).exists?
      @alerts = AdminAlert.unresolved.recent.limit(10)

      # Analytics
      @visits_today = Ahoy::Visit.where("started_at >= ?", Date.current.beginning_of_day).count
      @visits_7d = Ahoy::Visit.where("started_at >= ?", 7.days.ago).count
      @visits_30d = Ahoy::Visit.where("started_at >= ?", 30.days.ago).count
      @pageviews_today = Ahoy::Event.where("time >= ?", Date.current.beginning_of_day).count
      @top_pages = Ahoy::Event.where("time >= ?", 7.days.ago)
                       .group("properties->>'controller'", "properties->>'action'")
                       .order("count_all DESC").limit(10).count
      @users_count = User.count
    end
  end
end
