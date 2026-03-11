require "test_helper"

class FullDataSyncJobTest < ActiveSupport::TestCase
  test "job is enqueued on default queue" do
    assert_equal "default", FullDataSyncJob.new.queue_name
  end

  test "job includes Alertable concern" do
    assert FullDataSyncJob.ancestors.include?(Alertable)
  end

  test "perform accepts start_year and end_year parameters" do
    method = FullDataSyncJob.instance_method(:perform)
    params = method.parameters
    assert params.any? { |_, name| name == :start_year }
    assert params.any? { |_, name| name == :end_year }
  end

  test "mark_season_end_standings marks last race standings" do
    job = FullDataSyncJob.new
    # Call private method directly
    job.send(:mark_season_end_standings)

    # Melbourne 2025 is season_end race with standings
    standings = DriverStanding.where(race: races(:melbourne_2025))
    if standings.any?
      assert standings.first.season_end, "Last race standings should be marked season_end"
    end
  end
end
