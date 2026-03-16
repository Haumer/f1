class FantasyPortfolio < ApplicationRecord
  belongs_to :user
  belongs_to :season

  has_many :transactions, class_name: "FantasyTransaction", dependent: :destroy
  has_many :snapshots, class_name: "FantasySnapshot", dependent: :destroy
  has_many :achievements, class_name: "FantasyAchievement", dependent: :destroy

  validates :user_id, uniqueness: { scope: :season_id }
  validates :cash, :starting_capital, presence: true

  after_create :alert_first_portfolio

  def stock_portfolio
    @stock_portfolio ||= FantasyStockPortfolio.find_by(user_id: user_id, season_id: season_id)
  end

  def portfolio_value
    cash + (stock_portfolio&.positions_value || 0)
  end

  def profit_loss
    stock_portfolio&.profit_loss || 0
  end

  # Total return: value - starting capital
  def total_return
    (portfolio_value - Fantasy::CreatePortfolio::STARTING_CAPITAL).round(2)
  end

  # Cash available after subtracting locked collateral from stock shorts
  def available_cash
    cash - (stock_portfolio&.total_collateral || 0)
  end

  def can_trade?(race)
    return false unless race&.starts_at
    (race.starts_at - 1.minute) > Time.current
  end

  def has_achievement?(key)
    achievements.exists?(key: key.to_s)
  end

  def value_change_since_last_race
    last_two = snapshots.order(created_at: :desc).limit(2).to_a
    return nil unless last_two.size >= 2
    last_two[0].value - last_two[1].value
  end

  private

  def alert_first_portfolio
    return if user.fantasy_portfolios.count > 1

    AdminAlert.create!(
      title: "New fantasy portfolio",
      message: "#{user.username} created their first fantasy portfolio (#{season.year}).",
      severity: "info",
      source: "FantasyPortfolio"
    )
  end
end
