module PortfolioCommon
  extend ActiveSupport::Concern

  def has_achievement?(key)
    achievements.exists?(key: key.to_s)
  end

  def value_change_since_last_race
    last_two = snapshots.order(created_at: :desc).limit(2).to_a
    return nil unless last_two.size >= 2
    last_two[0].value - last_two[1].value
  end
end
