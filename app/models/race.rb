class Race < ApplicationRecord
  belongs_to :circuit
  belongs_to :season
  has_many :race_results
  has_many :driver_ratings
  has_many :drivers, through: :race_results
  has_many :driver_standings

  scope :sorted, -> { order(date: :asc) }

  def highest_elo_race_result
    race_results.order(new_elo: :desc).first
  end

  def sorted_race_results
    race_results.order(position_order: :asc).first(3)
  end

  def average_elos
    race_results.pluck(:new_elo).sum / race_results.count
  end

  PODIUM_COLORS = {
    1 => "#C9B037",
    2 => "#808080",
    3 => "#cc6633",
  }
end
