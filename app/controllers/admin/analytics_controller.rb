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

      @visits = Ahoy::Visit.where("started_at >= ?", @since).count
      @pageviews = Ahoy::Event.where("time >= ?", @since).count
      @unique_visitors = Ahoy::Visit.where("started_at >= ?", @since).distinct.count(:visitor_token)

      @top_pages = Ahoy::Event.where("time >= ?", @since)
                       .group("properties->>'controller'", "properties->>'action'")
                       .order("count_all DESC").limit(15).count

      @users_with_activity = User.joins("INNER JOIN ahoy_visits ON ahoy_visits.user_id = users.id")
                                 .where("ahoy_visits.started_at >= ?", @since)
                                 .select("users.*, COUNT(ahoy_visits.id) as visit_count, MAX(ahoy_visits.started_at) as last_seen")
                                 .group("users.id")
                                 .order("visit_count DESC")
                                 .limit(20)

      @daily_visits = Ahoy::Visit.where("started_at >= ?", @since)
                          .group("DATE(started_at)")
                          .order("date_started_at")
                          .count
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
  end
end
