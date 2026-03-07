class AiAnalysis < ApplicationRecord
  belongs_to :race

  validates :analysis_type, presence: true
  validates :race_id, uniqueness: { scope: :analysis_type }

  scope :race_previews, -> { where(analysis_type: 'race_preview') }
  scope :latest, -> { order(generated_at: :desc) }

  def race_preview?
    analysis_type == 'race_preview'
  end
end
