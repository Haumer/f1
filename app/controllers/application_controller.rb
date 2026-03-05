class ApplicationController < ActionController::Base
  include AccentColorable
  include Pundit::Authorization

  before_action :set_current_champion_accent

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :current_season

  def current_season
    @_current_season ||= begin
      year = Setting.effective_today.year
      Season.find_by(year: year.to_s) || Season.sorted_by_year.first
    end
  end

  private

  def user_not_authorized
    redirect_to root_path, alert: "Not authorized."
  end
end
