require "test_helper"

class AdminAlertTest < ActiveSupport::TestCase
  setup do
    @alert = AdminAlert.create!(
      title: "Test alert",
      message: "Something went wrong",
      severity: "error",
      source: "TestJob"
    )
  end

  test "resolve! marks alert as resolved" do
    @alert.resolve!
    assert @alert.resolved
    assert @alert.resolved_at.present?
  end

  test "unresolved scope returns only unresolved alerts" do
    AdminAlert.create!(title: "Resolved one", message: "ok", severity: "info", source: "Test", resolved: true)
    unresolved = AdminAlert.unresolved
    assert unresolved.all? { |a| !a.resolved }
  end

  test "resolved scope returns only resolved alerts" do
    @alert.resolve!
    resolved = AdminAlert.resolved
    assert resolved.all?(&:resolved)
  end

  test "recent scope orders by created_at desc" do
    older = AdminAlert.create!(title: "Older", message: "old", severity: "warning", source: "Test", created_at: 1.day.ago)
    recent = AdminAlert.recent
    assert recent.first.created_at >= recent.last.created_at
  end
end
