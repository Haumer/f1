class Race < ApplicationRecord
  belongs_to :circuit
  has_many :race_results
  has_many :driver_ratings
  has_many :drivers, through: :race_results

  scope :sorted, -> { order(date: :asc) }

  def highest_elo_race_result
    race_results.order(new_elo: :desc).first
  end

  def sorted_race_results
    race_results.order(position_order: :asc).first(3)
  end
end
