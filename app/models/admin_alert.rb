class AdminAlert < ApplicationRecord
  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
  scope :recent, -> { order(created_at: :desc) }

  def resolve!
    update!(resolved: true, resolved_at: Time.current)
  end
end
