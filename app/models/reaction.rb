class Reaction < ApplicationRecord
  KINDS = %w[fire flag skull heart].freeze

  KIND_META = {
    "fire"  => { emoji: "🔥", label: "Fire" },
    "flag"  => { emoji: "🏁", label: "Flag" },
    "skull" => { emoji: "💀", label: "Skull" },
    "heart" => { emoji: "❤️", label: "Heart" }
  }.freeze

  belongs_to :user
  belongs_to :reactable, polymorphic: true

  validates :kind, inclusion: { in: KINDS }
  validates :user_id, uniqueness: { scope: [:reactable_type, :reactable_id, :kind] }

  scope :of_kind, ->(k) { where(kind: k) }
end
