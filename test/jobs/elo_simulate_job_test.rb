require "test_helper"

class EloSimulateJobTest < ActiveSupport::TestCase
  test "job is enqueued on default queue" do
    assert_equal "default", EloSimulateJob.new.queue_name
  end

  test "job includes Alertable concern" do
    assert EloSimulateJob.ancestors.include?(Alertable)
  end

  test "perform runs both Elo simulators without error" do
    # The fixture data is small enough to simulate directly
    result = EloRatingV2.simulate_all!
    assert result[:drivers_updated] >= 0
    assert result[:race_results_updated] >= 0

    result2 = ConstructorEloV2.simulate_all!
    assert result2[:constructors_updated] >= 0
  end
end
