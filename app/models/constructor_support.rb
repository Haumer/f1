class ConstructorSupport < ApplicationRecord
  BONUS_CASH = 0

  belongs_to :user
  belongs_to :constructor
  belongs_to :season

  scope :active, -> { where(active: true) }

  def self.current_for(user, season)
    find_by(user: user, season: season, active: true)
  end

  # Can the user change their support this season?
  # Rules: locked after first pick until mid-season, then one swap allowed
  def self.can_change?(user, season)
    current = current_for(user, season)
    return true if current.nil? # never picked yet

    past_midseason?(season) && !swapped_after_midseason?(user, season)
  end

  def self.past_midseason?(season)
    total = season.races.count
    return false if total == 0
    completed = season.races.joins(:race_results).distinct.count
    completed >= (total / 2.0).ceil
  end

  def self.swapped_after_midseason?(user, season)
    # If there's an ended support created after the first active one,
    # or if the current active one was created after midseason point
    supports = where(user: user, season: season).order(:created_at)
    supports.count > 1 # they've already changed once (original + swap = 2 records)
  end
end
