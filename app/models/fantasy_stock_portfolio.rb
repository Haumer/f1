class FantasyStockPortfolio < ApplicationRecord
  belongs_to :user
  belongs_to :season

  has_many :holdings, class_name: "FantasyStockHolding", dependent: :destroy
  has_many :transactions, class_name: "FantasyStockTransaction", dependent: :destroy
  has_many :snapshots, class_name: "FantasyStockSnapshot", dependent: :destroy

  validates :user_id, uniqueness: { scope: :season_id }
  validates :cash, :starting_capital, presence: true

  PRICE_DIVISOR = 10.0
  MAX_POSITIONS = 6
  CAPITAL_MULTIPLIER = 2.2

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
    Fantasy::Pricing.price_for(driver, season) / PRICE_DIVISOR
  end

  def portfolio_value
    active = holdings.loaded? ? holdings.select(&:active) : active_holdings.includes(:driver).to_a
    longs_value = active.select { |h| h.direction == "long" }.sum do |h|
      share_price(h.driver) * h.quantity
    end
    shorts_value = active.select { |h| h.direction == "short" }.sum do |h|
      (h.entry_price - share_price(h.driver)) * h.quantity
    end
    cash + longs_value + shorts_value
  end

  def profit_loss
    portfolio_value - starting_capital
  end

  def can_trade?(race)
    return false unless race
    cutoff = race.starts_at || race.date&.beginning_of_day
    return false unless cutoff
    cutoff > Time.current
  end

  def total_collateral
    active_shorts.sum(:collateral)
  end

  def available_cash
    cash - total_collateral
  end

  def value_change_since_last_race
    last_two = snapshots.order(created_at: :desc).limit(2).to_a
    return nil if last_two.size < 2
    last_two[0].value - last_two[1].value
  end
end
