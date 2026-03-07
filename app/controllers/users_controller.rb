class UsersController < ApplicationController
  before_action :authenticate_user!, only: [:show, :update]

  def username_available
    username = params[:username].to_s.strip.downcase
    available = username.length >= 3 &&
                username.match?(User::USERNAME_FORMAT) &&
                !User::RESERVED_USERNAMES.include?(username) &&
                !User.where.not(id: current_user&.id).exists?(["LOWER(username) = ?", username])

    render json: { available: available }
  end

  def show
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
        render :show, status: :unprocessable_entity
      end
    else
      if @user.update(user_params)
        redirect_to user_settings_path(@user.username), notice: "Settings saved."
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :public_profile)
  end

  def user_params_with_password
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
