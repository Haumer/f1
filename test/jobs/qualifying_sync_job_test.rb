require "test_helper"
require "minitest/mock"

class QualifyingSyncJobTest < ActiveJob::TestCase
  # melbourne_2026 (round 2) has no results; bahrain_2026 (round 1) has 4
  # race_results in fixtures, which sets the expected grid size for round 2.
  setup do
    @race = races(:melbourne_2026)
    @race.update!(quali_time: "06:00:00") # quali_date is race date - 1 day
    @quali_start = @race.quali_starts_at
  end

  def stub_updater(count, source: "jolpica")
    updater = Minitest::Mock.new
    updater.expect(:call, count)
    updater.expect(:source, source) if count >= QualifyingSyncJob.expected_grid_size(@race)
    UpdateQualifyingResult.stub(:new, ->(*) { updater }) { yield }
    updater.verify
  end

  test "job is enqueued on default queue" do
    assert_equal "default", QualifyingSyncJob.new.queue_name
  end

  test "expected grid size comes from the previous race with results, not the season driver list" do
    assert_equal 4, races(:bahrain_2026).race_results.count
    assert_equal 4, QualifyingSyncJob.expected_grid_size(@race)
  end

  test "expected grid size falls back to active season drivers for the first race" do
    assert_equal 4, QualifyingSyncJob.expected_grid_size(races(:bahrain_2026))
  end

  test "poll window opens an hour after qualifying starts and closes a day after" do
    assert_equal @quali_start + 1.hour, QualifyingSyncJob.poll_opens_at(@race)
    assert_equal @quali_start + 24.hours, QualifyingSyncJob.poll_deadline(@race)
    assert_nil QualifyingSyncJob.poll_opens_at(races(:bahrain_2025)), "no quali time means no window"
  end

  test "skips without fetching when the classification is already complete" do
    4.times do |i|
      QualifyingResult.create!(race: @race, driver: SeasonDriver.where(season: @race.season).offset(i).first.driver, position: i + 1)
    end

    UpdateQualifyingResult.stub(:new, ->(*) { flunk "must not fetch" }) do
      assert_no_enqueued_jobs { QualifyingSyncJob.perform_now(race_id: @race.id) }
    end
  end

  test "stops polling once a full classification lands" do
    travel_to @quali_start + 2.hours do
      stub_updater(4) do
        assert_no_enqueued_jobs { QualifyingSyncJob.perform_now(race_id: @race.id, attempt: 3) }
      end
    end
    assert_empty AdminAlert.all
  end

  test "re-polls every two minutes while nothing has been published and the window is open" do
    travel_to @quali_start + 2.hours do
      stub_updater(0) do
        QualifyingSyncJob.perform_now(race_id: @race.id, attempt: 7)
      end

      assert_enqueued_with(job: QualifyingSyncJob, args: [{ race_id: @race.id, attempt: 8 }], at: Time.current + 2.minutes)
    end
    assert_empty AdminAlert.all
  end

  test "keeps polling on a partial classification" do
    travel_to @quali_start + 2.hours do
      stub_updater(2) do
        QualifyingSyncJob.perform_now(race_id: @race.id)
      end
      assert_enqueued_with(job: QualifyingSyncJob, args: [{ race_id: @race.id, attempt: 2 }])
    end
  end

  test "flags an admin alert instead of re-polling once the window has closed" do
    travel_to @quali_start + 24.hours + 1.minute do
      stub_updater(0) do
        assert_no_enqueued_jobs { QualifyingSyncJob.perform_now(race_id: @race.id, attempt: 690) }
      end
    end

    alert = AdminAlert.last
    assert_equal "QualifyingSyncJob", alert.source
    assert_equal "warning", alert.severity
    assert_match(/Qualifying results missing: R2 2026/, alert.title)
    assert_match(/No qualifying results stored/, alert.message)
    assert_match(/690 times/, alert.message)
    assert_match(/rake f1:qualifying YEAR=2026/, alert.message)
  end

  test "the closing alert reports a partial classification as such" do
    travel_to @quali_start + 25.hours do
      stub_updater(3) { QualifyingSyncJob.perform_now(race_id: @race.id) }
    end

    assert_match(/Only 3 of 4 qualifying results/, AdminAlert.last.message)
  end

  test "skips cancelled races" do
    @race.update!(cancelled: true)
    UpdateQualifyingResult.stub(:new, ->(*) { flunk "must not fetch" }) do
      assert_no_enqueued_jobs { QualifyingSyncJob.perform_now(race_id: @race.id) }
    end
  end

  test "polling? reflects unfinished jobs on the queue" do
    assert_not QualifyingSyncJob.polling?
  end
end
