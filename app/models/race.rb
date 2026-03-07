class Race < ApplicationRecord
  belongs_to :circuit
  belongs_to :season
  has_many :race_results, dependent: :destroy
  has_many :qualifying_results, dependent: :destroy
  has_many :drivers, through: :race_results
  has_many :driver_standings, dependent: :destroy
  has_many :predictions, dependent: :destroy

  validates :date, :round, presence: true
  validates :round, uniqueness: { scope: :season_id }

  scope :sorted, -> { order(date: :asc) }
  scope :sorted_by_most_recent, -> { order(date: :desc) }

  def highest_elo_race_result
    race_results.order(new_elo: :desc).first
  end

  def sorted_race_results
    race_results.order(position_order: :asc).first(3)
  end

  def average_elos
    return 0 if race_results.count.zero?

    race_results.pluck(:new_elo).compact.sum.to_f / race_results.count
  end

  def previous_race
    if round == 1
      season.previous_season&.last_race
    else
      season.races.find_by(round: round - 1)
    end
  end

  def next_race
    last = season.last_race
    if last && round == last.round
      season.next_season&.first_race
    else
      season.races.find_by(round: round + 1)
    end
  end

  def driver_standing_for(driver)
    driver_standings.find_by(driver: driver)
  end

  # Returns race start as a UTC Time, combining date + time columns
  def starts_at
    return nil unless time.present?
    Time.parse("#{date}T#{time}")
  end

  # Session dates computed from race date (standard weekend layout)
  def fp1_date  = date - 2.days
  def fp2_date  = date - 2.days
  def fp3_date  = date - 1.day
  def quali_date = date - 1.day

  def fp1_starts_at
    fp1_time.present? ? Time.parse("#{fp1_date}T#{fp1_time}") : nil
  end

  def fp2_starts_at
    fp2_time.present? ? Time.parse("#{fp2_date}T#{fp2_time}") : nil
  end

  def fp3_starts_at
    fp3_time.present? ? Time.parse("#{fp3_date}T#{fp3_time}") : nil
  end

  def quali_starts_at
    quali_time.present? ? Time.parse("#{quali_date}T#{quali_time}") : nil
  end

  # Structured session schedule for views
  def session_schedule
    [
      { key: :fp1,   name: "FP1",        date: fp1_date,   starts_at: fp1_starts_at },
      { key: :fp2,   name: "FP2",        date: fp2_date,   starts_at: fp2_starts_at },
      { key: :fp3,   name: "FP3",        date: fp3_date,   starts_at: fp3_starts_at },
      { key: :quali, name: "Qualifying", date: quali_date, starts_at: quali_starts_at },
      { key: :race,  name: "Race",       date: date,       starts_at: starts_at },
    ]
  end

  def has_results?
    race_results.any?
  end

  PODIUM_COLORS = {
    1 => "#C9B037",
    2 => "#808080",
    3 => "#cc6633",
  }
end
