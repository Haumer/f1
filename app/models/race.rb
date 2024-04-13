class Race < ApplicationRecord
  belongs_to :circuit
  belongs_to :season
  has_many :race_results, dependent: :destroy
  has_many :drivers, through: :race_results
  has_many :driver_standings, dependent: :destroy

  scope :sorted, -> { order(date: :asc) }
  scope :sorted_by_most_recent, -> { order(date: :desc) }

  def highest_elo_race_result
    race_results.order(new_elo: :desc).first
  end

  def sorted_race_results
    race_results.order(position_order: :asc).first(3)
  end

  def average_elos
    race_results.pluck(:new_elo).sum / race_results.count
  end

  def previous_race
    round == 1 ? season.previous_season.last_race : season.races.find_by(round: round - 1)
  end

  def next_race
    if round == season.last_race.round
      if season.next_season
        season.next_season.first_race
      end
    else
      season.races.find_by(round: round + 1)
    end
  end

  def driver_standing_for(driver)
    driver_standings.find_by(driver: driver)
  end

  PODIUM_COLORS = {
    1 => "#C9B037",
    2 => "#808080",
    3 => "#cc6633",
  }
end
