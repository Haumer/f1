module AchievementModel
  extend ActiveSupport::Concern

  included do
    validates :key, presence: true
    validates :tier, inclusion: { in: %w[bronze silver gold] }
  end

  def definition
    self.class::DEFINITIONS[key.to_sym] || {}
  end

  def name
    definition[:name] || key.humanize
  end

  def description
    definition[:description] || ""
  end

  def icon
    definition[:icon] || "fa-star"
  end
end
