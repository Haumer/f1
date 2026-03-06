class EloSimulateJob < ApplicationJob
  include Alertable
  limits_concurrency to: 1, key: "elo_simulate"

  queue_as :default

  def perform
    EloRatingV2.simulate_all!
    ConstructorEloV2.simulate_all!
  end
end
