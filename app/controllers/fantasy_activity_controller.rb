class FantasyActivityController < ApplicationController
  before_action :authenticate_user!
  before_action :load_user_from_username
  before_action :require_owner!

  def index
    @season = Season.order(year: :desc).first
    @entries = Fantasy::ActivityFeed.for_user(@user, season: @season, limit: 500)
  end

  private

  def load_user_from_username
    @user = User.find_by!(username: params[:username])
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError, "User not found"
  end

  def require_owner!
    return if user_signed_in? && current_user == @user
    flash[:alert] = "You can only view your own activity."
    redirect_to fantasy_overview_path(@user.username)
  end
end
