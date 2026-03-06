class BackfillCareersJob < ApplicationJob
  include Alertable
  limits_concurrency to: 1, key: "backfill_careers"

  queue_as :default

  def perform
    Driver.find_each do |driver|
      UpdateDriverCareer.new(driver: driver).update
    end
  end
end
