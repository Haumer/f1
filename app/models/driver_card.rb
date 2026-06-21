class DriverCard < ApplicationRecord
  belongs_to :user
  belongs_to :driver
  belongs_to :race

  TIERS = %w[bronze silver gold platinum legendary].freeze

  validates :predicted_position, :actual_position, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 30, only_integer: true }
  validates :tier, inclusion: { in: TIERS }
  validates :user_id, uniqueness: { scope: %i[driver_id race_id] }

  scope :for_user, ->(user) { where(user: user) }
  scope :by_tier, ->(tier) { where(tier: tier) }

  def combined?
    combined_from_race_ids.present? && combined_from_race_ids.any?
  end

  def self.next_tier(tier)
    idx = TIERS.index(tier)
    return nil if idx.nil? || idx >= TIERS.size - 1
    TIERS[idx + 1]
  end
end
