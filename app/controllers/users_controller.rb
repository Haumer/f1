class UsersController < ApplicationController
  before_action :authenticate_user!, only: [:settings, :update]

  def username_available
    username = params[:username].to_s.strip.downcase
    available = username.length >= 3 &&
                username.match?(User::USERNAME_FORMAT) &&
                !User::RESERVED_USERNAMES.include?(username) &&
                !User.where.not(id: current_user&.id).exists?(["LOWER(username) = ?", username])

    render json: { available: available }
  end

  # Public profile — anyone can view (subject to public_profile flag).
  def profile
    @user = User.find_by!(username: params[:username])
    @is_owner = @user == current_user

    if !@user.public_profile? && !@is_owner
      redirect_to root_path, alert: "This profile is private." and return
    end

    load_profile_data
  end

  # Owner-only settings page (was users#show).
  def settings
    @user = User.find_by!(username: params[:username])
    redirect_to root_path, alert: "Not authorized." unless @user == current_user
  end

  def update
    @user = User.find_by!(username: params[:username])
    redirect_to root_path, alert: "Not authorized." and return unless @user == current_user

    if params[:user][:password].present?
      if @user.update_with_password(user_params_with_password)
        bypass_sign_in(@user)
        redirect_to user_settings_path(@user.username), notice: "Password updated."
      else
        render :settings, status: :unprocessable_entity
      end
    else
      if @user.update(user_params)
        redirect_to user_settings_path(@user.username), notice: "Settings saved."
      else
        render :settings, status: :unprocessable_entity
      end
    end
  end

  private

  def load_profile_data
    @current_season = Season.sorted_by_year.first
    @supported_constructor = @user.supported_constructor(@current_season)
    @team_color = @user.team_color(@current_season)

    @stock_portfolio = @user.fantasy_stock_portfolio_for(@current_season)
    @stock_rank = @stock_portfolio&.snapshots&.order(created_at: :desc)&.first&.rank

    @recent_picks = RacePick.where(user_id: @user.id)
                            .where.not(picks: [])
                            .order(created_at: :desc)
                            .limit(5)
                            .includes(:race)

    @latest_h2h = DriverPreferenceSession
                    .where(user_id: @user.id)
                    .where.not(champion_driver_id: nil)
                    .order(finished_at: :desc)
                    .limit(1)
                    .includes(:champion_driver)
                    .first

    @reactions_received = tally_reactions_received(@user)
  end

  # Aggregate reaction counts across all four reactable types owned by user.
  def tally_reactions_received(user)
    reactable_ids = {
      "Prediction" => Prediction.where(user_id: user.id).pluck(:id),
      "RacePick" => RacePick.where(user_id: user.id).pluck(:id),
      "DriverPreferenceSession" => DriverPreferenceSession.where(user_id: user.id).pluck(:id),
      "FantasyStockHolding" => FantasyStockHolding
                                 .joins(:fantasy_stock_portfolio)
                                 .where(fantasy_stock_portfolios: { user_id: user.id })
                                 .pluck(:id)
    }

    totals = Hash.new(0)
    reactable_ids.each do |type, ids|
      next if ids.empty?

      Reaction.where(reactable_type: type, reactable_id: ids).group(:kind).count.each do |kind, count|
        totals[kind] += count
      end
    end
    totals
  end

  def user_params
    params.require(:user).permit(:username, :public_profile)
  end

  def user_params_with_password
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
