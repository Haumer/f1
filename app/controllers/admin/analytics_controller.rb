module Admin
  class AnalyticsController < BaseController
    def index
      @period = params[:period] || "7d"
      @since = case @period
               when "today" then Date.current.beginning_of_day
               when "7d" then 7.days.ago
               when "30d" then 30.days.ago
               when "all" then Time.at(0)
               else 7.days.ago
               end

      @excluded_ids = Setting.analytics_excluded_user_ids
      visits_scope = Ahoy::Visit.where.not(user_id: @excluded_ids)
      events_scope = Ahoy::Event.joins(:visit).where.not(ahoy_visits: { user_id: @excluded_ids })

      @visits = visits_scope.where("started_at >= ?", @since).count
      @pageviews = events_scope.where("ahoy_events.time >= ?", @since).count
      @unique_visitors = visits_scope.where("started_at >= ?", @since).distinct.count(:visitor_token)

      @top_pages = events_scope.where("ahoy_events.time >= ?", @since)
                       .group("ahoy_events.properties->>'controller'", "ahoy_events.properties->>'action'")
                       .order("count_all DESC").limit(15).count

      @users_with_activity = User.joins("INNER JOIN ahoy_visits ON ahoy_visits.user_id = users.id")
                                 .where("ahoy_visits.started_at >= ?", @since)
                                 .where.not("users.id" => @excluded_ids)
                                 .select("users.*, COUNT(ahoy_visits.id) as visit_count, MAX(ahoy_visits.started_at) as last_seen")
                                 .group("users.id")
                                 .order("visit_count DESC")
                                 .limit(20)

      @daily_visits = visits_scope.where("started_at >= ?", @since)
                          .group("DATE(started_at)")
                          .order("date_started_at")
                          .count

      # Top users by all-time visits for the exclusion panel
      @top_users_for_exclusion = User.joins("INNER JOIN ahoy_visits ON ahoy_visits.user_id = users.id")
                                     .select("users.*, COUNT(ahoy_visits.id) as total_visits")
                                     .group("users.id")
                                     .order(Arel.sql("COUNT(ahoy_visits.id) DESC"))
                                     .limit(20)
                                     .to_a
    end

    def show
      @user = User.find_by!(username: params[:id])
      @visits = Ahoy::Visit.where(user: @user).order(started_at: :desc).limit(20)
      @recent_pages = Ahoy::Event.where(user: @user).order(time: :desc).limit(50)
      @total_visits = Ahoy::Visit.where(user: @user).count
      @total_pageviews = Ahoy::Event.where(user: @user).count
      @first_visit = Ahoy::Visit.where(user: @user).minimum(:started_at)
      @top_pages = Ahoy::Event.where(user: @user)
                       .group("properties->>'controller'", "properties->>'action'")
                       .order("count_all DESC").limit(10).count
    end

    def toggle_exclusion
      user = User.find(params[:user_id])
      if Setting.analytics_excluded_user_ids.include?(user.id)
        Setting.analytics_include_user!(user.id)
        redirect_to admin_analytics_path(period: params[:period]), notice: "#{user.username} included in analytics."
      else
        Setting.analytics_exclude_user!(user.id)
        redirect_to admin_analytics_path(period: params[:period]), notice: "#{user.username} excluded from analytics."
      end
    end
  end
end
