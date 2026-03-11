require "test_helper"

class BackfillCareersJobTest < ActiveSupport::TestCase
  test "job is enqueued on default queue" do
    assert_equal "default", BackfillCareersJob.new.queue_name
  end

  test "job includes Alertable concern" do
    assert BackfillCareersJob.ancestors.include?(Alertable)
  end

  test "perform updates career for all drivers" do
    BackfillCareersJob.new.perform

    drivers(:verstappen).reload
    assert drivers(:verstappen).wins.present?
  end
end
