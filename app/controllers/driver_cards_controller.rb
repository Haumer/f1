class DriverCardsController < ApplicationController
  before_action :authenticate_user!, only: [:combine]
  before_action :load_user_from_username
  before_action :require_public_or_owner!, only: [:index, :show]
  before_action :require_owner!, only: [:combine]

  helper_method :is_owner?

  def index
    @cards = DriverCard
      .where(user: @user)
      .includes(:driver, race: [:circuit, :season])
      .order(earned_at: :desc)

    @stacks = @cards.group_by(&:driver_id)

    @counts_by_tier = @cards.group_by(&:tier).transform_values(&:count)
    @unique_drivers = @stacks.size
    @total          = @cards.size
  end

  def show
    @card = DriverCard.includes(:driver, race: [:circuit, :season])
                      .where(user: @user)
                      .find(params[:id])
  end

  def combine
    driver = Driver.find(params[:driver_id])
    new_card = DriverCards::Combine.call(user: @user, driver: driver, tier: params[:tier])
    flash[:notice] = "Combined 3 #{params[:tier].capitalize} #{driver.surname} cards into a #{new_card.tier.capitalize}."
    redirect_back fallback_location: driver_cards_path(username: @user.username)
  rescue DriverCards::Combine::Error => e
    flash[:alert] = e.message
    redirect_back fallback_location: driver_cards_path(username: @user.username)
  end

  private

  def load_user_from_username
    @user = User.find_by!(username: params[:username])
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError, "User not found"
  end

  def is_owner?
    user_signed_in? && current_user == @user
  end

  def require_owner!
    return if is_owner?
    flash[:alert] = "You can only combine your own cards."
    redirect_to driver_cards_path(username: @user.username)
  end

  def require_public_or_owner!
    return if is_owner? || @user.public_profile?
    redirect_to combined_leaderboard_path, alert: "This profile is private."
  end
end
