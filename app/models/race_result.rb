class RaceResult < ApplicationRecord
  belongs_to :race
  belongs_to :constructor
  belongs_to :status
  belongs_to :driver

  def elo_diff
    new_elo - old_elo
  end

  def gained_elo?
    elo_diff.positive?
  end
end
