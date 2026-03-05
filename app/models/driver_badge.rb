class DriverBadge < ApplicationRecord
  belongs_to :driver

  scope :ordered_by_tier, -> {
    order(Arel.sql("CASE tier WHEN 'gold' THEN 0 WHEN 'silver' THEN 1 WHEN 'bronze' THEN 2 ELSE 3 END"))
  }

  scope :circuit_kings_for, ->(circuit_id) {
    where(key: "circuit_king_#{circuit_id}").includes(:driver).ordered_by_tier
  }
end
