class UsersController < ApplicationController
  def username_available
    username = params[:username].to_s.strip.downcase
    available = username.length >= 3 &&
                username.match?(User::USERNAME_FORMAT) &&
                !User::RESERVED_USERNAMES.include?(username) &&
                !User.where.not(id: current_user&.id).exists?(["LOWER(username) = ?", username])

    render json: { available: available }
  end
end
