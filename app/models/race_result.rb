class RaceResult < ApplicationRecord
  belongs_to :race
  has_one :season, through: :race
  belongs_to :constructor
  belongs_to :status
  belongs_to :driver

  validates :driver_id, :race_id, :constructor_id, presence: true

  def elo_diff
    return 0 unless new_elo_v2 && old_elo_v2
    new_elo_v2 - old_elo_v2
  end

  def gained_elo?
    elo_diff.positive?
  end

  def display_old_elo
    old_elo_v2
  end

  def display_new_elo
    new_elo_v2
  end

  def display_elo_diff
    elo_diff
  end

  def display_gained_elo?
    gained_elo?
  end
end
