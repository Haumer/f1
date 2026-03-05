class ComputeBadgesJob < ApplicationJob
  include Alertable

  queue_as :default

  def perform
    DriverBadges.compute_all_drivers!
  end
end
