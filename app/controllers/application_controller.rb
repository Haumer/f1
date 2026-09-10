class ApplicationController < ActionController::Base
  include AccentColorable
  include Pundit::Authorization

  after_action :track_action

  before_action :redirect_to_canonical_host
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

  protected

  # Devise: restore pending picks after sign in or sign up
  def after_sign_in_path_for(resource)
    if session[:pending_picks].present? && session[:pending_picks_race_id].present?
      race = Race.find_by(id: session[:pending_picks_race_id])
      picks_restored = false
      if race
        payload = Fantasy::RacePickPayload.new(raw: session[:pending_picks], race: race).call
        if payload.success? && race.picks_open?
          pick = RacePick.find_or_initialize_by(user: resource, race: race)
          unless pick.locked?
            pick.picks = payload.picks
            pick.locked_at = race.starts_at
            pick.save!
            picks_restored = true
          end
        end
      end
      session.delete(:pending_picks)
      session.delete(:pending_picks_race_id)
      if picks_restored
        flash[:notice] = "Your picks for #{race.circuit.name} have been saved!"
      else
        flash[:alert] = "Your account is ready, but those picks could not be saved."
      end
      return fantasy_overview_path(resource.username)
    end

    super
  end

  private

  def redirect_to_canonical_host
    return unless Rails.env.production?
    return if request.host == PublicSite.host

    redirect_to PublicSite.url(request.fullpath), status: :moved_permanently, allow_other_host: true
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :terms_accepted])
    devise_parameter_sanitizer.permit(:account_update, keys: [:username])
  end

  def user_not_authorized
    redirect_to root_path, alert: "Not authorized."
  end

  def track_action
    return unless request.get?
    return unless request.format.html?
    return if self.class.module_parent == Admin
    return if request.path == "/users/username_available"
    return if request.path == "/drivers/search"

    ahoy.track "Page View", request.path_parameters.merge(url: request.path)
  end
end
