require "test_helper"

class AlertableTest < ActiveSupport::TestCase
  # Create a minimal test job that includes Alertable
  class FailingJob < ApplicationJob
    include Alertable
    queue_as :default

    def perform
      raise "test boom"
    end
  end

  test "creates admin alert on job failure and re-raises" do
    assert_raises(RuntimeError) do
      FailingJob.perform_now
    end

    alert = AdminAlert.order(created_at: :desc).first
    assert alert.present?
    assert_match(/FailingJob/, alert.title)
    assert_includes alert.message, "test boom"
    assert_equal "error", alert.severity
  end
end
