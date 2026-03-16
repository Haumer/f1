class FantasyStockPortfolio < ApplicationRecord
  belongs_to :user
  belongs_to :season

  has_many :holdings, class_name: "FantasyStockHolding", dependent: :destroy
  has_many :transactions, class_name: "FantasyStockTransaction", dependent: :destroy
  has_many :snapshots, class_name: "FantasyStockSnapshot", dependent: :destroy
  has_many :achievements, class_name: "FantasyStockAchievement", dependent: :destroy

  validates :user_id, uniqueness: { scope: :season_id }
  validates :starting_capital, presence: true

  PRICE_DIVISOR = 10.0
  MAX_POSITIONS = 6
  COLLATERAL_RATIO = 0.5 # 50% margin requirement for shorts

  # Unified cash: stock portfolio uses roster portfolio as its wallet
  def wallet
    @wallet ||= FantasyPortfolio.find_by(user_id: user_id, season_id: season_id)
  end

  def active_holdings
    holdings.where(active: true)
  end

  def active_longs
    active_holdings.where(direction: "long")
  end

  def active_shorts
    active_holdings.where(direction: "short")
  end

  def position_count
    active_holdings.count
  end

  def positions_full?
    position_count >= MAX_POSITIONS
  end

  def share_price(driver)
    Fantasy::Pricing.stock_price_for(driver, season)
  end

  # Positions-only value (no cash — cash lives in the wallet/roster portfolio)
  def positions_value
    active = holdings.loaded? ? holdings.select(&:active) : active_holdings.includes(:driver).to_a
    longs_value = active.select { |h| h.direction == "long" }.sum do |h|
      share_price(h.driver) * h.quantity
    end
    shorts_pnl = active.select { |h| h.direction == "short" }.sum do |h|
      (h.entry_price - share_price(h.driver)) * h.quantity
    end
    longs_value + shorts_pnl
  end

  # Total invested = sum of what was spent opening positions
  def total_invested
    active = holdings.loaded? ? holdings.select(&:active) : active_holdings.to_a
    active.select { |h| h.direction == "long" }.sum { |h| h.entry_price * h.quantity }
  end

  # Stock P&L = current positions value - total invested
  def profit_loss
    (positions_value - total_invested).round(2)
  end

  # For backward compat — portfolio_value now means positions only
  def portfolio_value
    positions_value
  end

  def can_trade?(race)
    return false unless race
    cutoff = race.starts_at || race.date&.beginning_of_day
    return false unless cutoff
    (cutoff - 1.minute) > Time.current
  end

  def total_collateral
    active_shorts.sum(:collateral)
  end

  def available_cash
    (wallet&.cash || 0) - total_collateral
  end

  def has_achievement?(key)
    achievements.exists?(key: key.to_s)
  end

  def value_change_since_last_race
    last_two = snapshots.order(created_at: :desc).limit(2).to_a
    return nil unless last_two.size >= 2
    last_two[0].value - last_two[1].value
  end
end
