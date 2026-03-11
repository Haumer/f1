class RacePick < ApplicationRecord
  belongs_to :user
  belongs_to :race

  validates :user_id, uniqueness: { scope: :race_id }

  # picks format: [{ "driver_id" => 1, "position" => 1, "source" => "manual"|"random" }, ...]

  def locked?
    locked_at.present? && Time.current >= locked_at
  end

  def placed_drivers
    (picks || []).sort_by { |p| p["position"] }
  end

  def manual_picks
    (picks || []).select { |p| p["source"] == "manual" }
  end

  def filled_positions
    (picks || []).size
  end
end
