require "test_helper"

class ComputeBadgesJobTest < ActiveSupport::TestCase
  test "job is enqueued on default queue" do
    assert_equal "default", ComputeBadgesJob.new.queue_name
  end

  test "job includes Alertable concern" do
    assert ComputeBadgesJob.ancestors.include?(Alertable)
  end

  test "perform executes without error" do
    ComputeBadgesJob.new.perform
    # If it runs without raising, it called DriverBadges.compute_all_drivers! successfully
  end
end
