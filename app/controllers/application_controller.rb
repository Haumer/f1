class ApplicationController < ActionController::Base
  include AccentColorable
  include Pundit::Authorization

  after_action :track_action

  before_action :set_current_champion_accent
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :current_season

  def current_season
    @_current_season ||= begin
      year = Setting.effective_today.year
      Season.find_by(year: year.to_s) || Season.sorted_by_year.first
    end
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username])
    devise_parameter_sanitizer.permit(:account_update, keys: [:username])
  end

  def user_not_authorized
    redirect_to root_path, alert: "Not authorized."
  end

  def track_action
    ahoy.track "Page View", request.path_parameters.merge(url: request.url)
  end
end
