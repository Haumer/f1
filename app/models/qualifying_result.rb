class QualifyingResult < ApplicationRecord
  belongs_to :race
  belongs_to :driver
  belongs_to :constructor, optional: true

  scope :sorted, -> { order(:position) }

  # Best time from the latest qualifying session the driver participated in
  def best_time
    q3.presence || q2.presence || q1.presence
  end

  # Gap in seconds to another lap time string, formatted as "0.293"
  def gap_to(other_time)
    return nil unless best_time && other_time
    diff = parse_lap(best_time) - parse_lap(other_time)
    diff.round(3).to_s
  end

  private

  def parse_lap(time_str)
    parts = time_str.split(":")
    parts[-2].to_f * 60 + parts[-1].to_f
  end
end
