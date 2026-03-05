class BackfillCareersJob < ApplicationJob
  include Alertable

  queue_as :default

  def perform
    Driver.find_each do |driver|
      UpdateDriverCareer.new(driver: driver).update
    end
  end
end
