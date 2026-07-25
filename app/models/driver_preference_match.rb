class DriverPreferenceMatch < ApplicationRecord
  belongs_to :driver_preference_session
  belongs_to :winner_driver, class_name: "Driver"
  belongs_to :loser_driver,  class_name: "Driver"

  validates :year, :round_index, :tier, presence: true
  validates :round_index, uniqueness: { scope: :driver_preference_session_id }
end
