module Reactable
  extend ActiveSupport::Concern

  included do
    has_many :reactions, as: :reactable, dependent: :destroy
  end

  # Returns { "fire" => 3, "heart" => 1, ... } — omits kinds with 0.
  def reaction_counts
    @reaction_counts ||= reactions.group(:kind).count
  end

  # Returns the set of kinds the given user has reacted with.
  def reaction_kinds_for(user)
    return Set.new unless user

    Set.new(reactions.where(user_id: user.id).pluck(:kind))
  end
end
