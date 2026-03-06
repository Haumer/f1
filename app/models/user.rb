class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  USERNAME_FORMAT = /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/
  RESERVED_USERNAMES = %w[admin root system support api about elo fantasy stocks
                          drivers races constructors seasons circuits stats settings].freeze

  validates :username, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { minimum: 3, maximum: 24 },
                       format: { with: USERNAME_FORMAT, message: "can only contain letters, numbers, hyphens, and underscores" }
  validate :username_not_reserved

  before_validation :normalize_username

  has_many :fantasy_portfolios, dependent: :destroy
  has_many :fantasy_stock_portfolios, dependent: :destroy
  belongs_to :supported_constructor, class_name: "Constructor", optional: true

  def to_param
    username
  end

  def fantasy_portfolio_for(season)
    fantasy_portfolios.find_by(season: season)
  end

  def fantasy_stock_portfolio_for(season)
    fantasy_stock_portfolios.find_by(season: season)
  end

  def display_name
    username
  end

  def team_color
    return nil unless supported_constructor
    Constructor::COLORS[supported_constructor.constructor_ref.to_sym]
  end

  private

  def normalize_username
    self.username = username&.strip&.downcase
  end

  def username_not_reserved
    errors.add(:username, "is reserved") if RESERVED_USERNAMES.include?(username&.downcase)
  end
end
