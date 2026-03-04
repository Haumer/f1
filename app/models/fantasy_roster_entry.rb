class FantasyRosterEntry < ApplicationRecord
  belongs_to :fantasy_portfolio
  belongs_to :driver
  belongs_to :bought_race, class_name: "Race", optional: true
  belongs_to :sold_race, class_name: "Race", optional: true

  scope :active, -> { where(active: true) }
  scope :sold, -> { where(active: false) }

  validates :bought_at_elo, presence: true

  def current_value
    driver.elo_v2 || 0
  end

  def gain_loss
    current_value - bought_at_elo
  end

  def gain_loss_percent
    return 0 if bought_at_elo.zero?
    (gain_loss / bought_at_elo * 100).round(1)
  end
end
