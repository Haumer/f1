class EloSimulateJob < ApplicationJob
  include Alertable

  queue_as :default

  def perform
    EloRatingV2.simulate_all!
    ConstructorEloV2.simulate_all!
  end
end
