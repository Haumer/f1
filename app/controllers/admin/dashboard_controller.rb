module Admin
  class DashboardController < BaseController
    def index
      @total_drivers = Driver.count
      @active_drivers = Driver.active.count
      @total_races = Race.count
      @total_seasons = Season.count
      @v2_populated = Driver.where.not(elo_v2: nil).exists?
      @alerts = AdminAlert.unresolved.recent.limit(10)

      # Analytics (excluding filtered users)
      excluded = Setting.analytics_excluded_user_ids
      visits_scope = Ahoy::Visit.where.not(user_id: excluded)
      events_scope = Ahoy::Event.joins(:visit).where.not(ahoy_visits: { user_id: excluded })

      @visits_today = visits_scope.where("started_at >= ?", Date.current.beginning_of_day).count
      @visits_7d = visits_scope.where("started_at >= ?", 7.days.ago).count
      @visits_30d = visits_scope.where("started_at >= ?", 30.days.ago).count
      @pageviews_today = events_scope.where("ahoy_events.time >= ?", Date.current.beginning_of_day).count
      @top_pages = events_scope.where("ahoy_events.time >= ?", 7.days.ago)
                       .group("ahoy_events.properties->>'controller'", "ahoy_events.properties->>'action'")
                       .order("count_all DESC").limit(10).count
      @users_count = User.count
      @excluded_count = excluded.size
    end
  end
end
