class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :fantasy_portfolios, dependent: :destroy
  has_many :fantasy_stock_portfolios, dependent: :destroy

  def fantasy_portfolio_for(season)
    fantasy_portfolios.find_by(season: season)
  end

  def fantasy_stock_portfolio_for(season)
    fantasy_stock_portfolios.find_by(season: season)
  end

  def display_name
    username.presence || email.split("@").first
  end
end
