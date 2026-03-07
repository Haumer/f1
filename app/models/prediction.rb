class Prediction < ApplicationRecord
  belongs_to :race
  belongs_to :user

  validates :race_id, uniqueness: { scope: :user_id }
  validates :predicted_results, presence: true

  scope :latest, -> { order(generated_at: :desc) }

  def predicted_drivers
    return [] unless predicted_results.present?

    driver_ids = predicted_results.map { |r| r["driver_id"] }
    drivers_by_id = Driver.where(id: driver_ids).index_by(&:id)
    predicted_results.sort_by { |r| r["position"] }.map do |r|
      { driver: drivers_by_id[r["driver_id"]], position: r["position"], grid: r["grid"] }
    end
  end

  def compute_elo_changes!
    self.elo_changes = EloPredictionService.compute(self)
    save!
  end
end
