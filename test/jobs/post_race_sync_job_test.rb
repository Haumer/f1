require "test_helper"

class PostRaceSyncJobTest < ActiveSupport::TestCase
  test "job is enqueued on default queue" do
    assert_equal "default", PostRaceSyncJob.new.queue_name
  end

  test "job includes Alertable concern" do
    assert PostRaceSyncJob.ancestors.include?(Alertable)
  end

  test "perform accepts year parameter" do
    # Verify the method signature accepts year keyword
    method = PostRaceSyncJob.instance_method(:perform)
    params = method.parameters
    assert params.any? { |type, name| name == :year }, "Should accept year parameter"
  end
end
