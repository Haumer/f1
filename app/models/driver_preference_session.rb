class DriverPreferenceSession < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :champion_driver, class_name: "Driver", optional: true
  has_many :matches,
           class_name: "DriverPreferenceMatch",
           foreign_key: :driver_preference_session_id,
           dependent: :destroy

  validates :session_token, :year, :started_at, presence: true

  def finished?
    finished_at.present? || rounds_played >= rounds_target
  end

  def top_ranked(limit = 5)
    # Champion-stays elimination order: the final champion is #1, then losers
    # ranked by how late they were eliminated (a driver who beat you and later
    # lost still ranks above you, because the last person to face them wins
    # transitively over yours). Raw win counts would mis-rank early-round
    # kings who later got knocked out by a stronger challenger.
    ordered = matches.order(:round_index).to_a
    return [] if ordered.empty?

    champion_id = ordered.last.winner_driver_id
    losers_latest_first = ordered.reverse.map(&:loser_driver_id)
    ids = ([champion_id] + losers_latest_first).uniq.first(limit)
    Driver.where(id: ids).index_by(&:id).values_at(*ids).compact
  end
end
