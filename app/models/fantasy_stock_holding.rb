class FantasyStockHolding < ApplicationRecord
  belongs_to :fantasy_stock_portfolio
  belongs_to :driver
  belongs_to :opened_race, class_name: "Race"
  belongs_to :closed_race, class_name: "Race", optional: true

  validates :quantity, numericality: { greater_than: 0 }
  validates :direction, inclusion: { in: %w[long short] }
  validates :entry_price, presence: true

  scope :active, -> { where(active: true) }
  scope :longs, -> { where(direction: "long") }
  scope :shorts, -> { where(direction: "short") }

  def long?
    direction == "long"
  end

  def short?
    direction == "short"
  end

  def current_price
    fantasy_stock_portfolio.share_price(driver)
  end

  def market_value
    if long?
      current_price * quantity
    else
      # Short P&L relative to entry
      (entry_price - current_price) * quantity
    end
  end

  def gain_loss
    if long?
      (current_price - entry_price) * quantity
    else
      (entry_price - current_price) * quantity
    end
  end

  def gain_loss_percent
    return 0 if entry_price.zero?
    total_cost = entry_price * quantity
    (gain_loss / total_cost * 100).round(1)
  end

  def races_held
    latest = fantasy_stock_portfolio.season.latest_race
    return 0 unless latest && opened_race
    latest.round - opened_race.round
  end
end
