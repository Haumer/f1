require "test_helper"

class QualifyingSyncJobTest < ActiveSupport::TestCase
  test "job is enqueued on default queue" do
    assert_equal "default", QualifyingSyncJob.new.queue_name
  end

  test "skips if qualifying results already complete" do
    race = races(:bahrain_2026)
    season = race.season
    expected = season.season_drivers.count

    # Create enough qualifying results to meet expected count
    expected.times do |i|
      QualifyingResult.find_or_create_by!(
        race: race,
        driver: SeasonDriver.where(season: season).offset(i).first&.driver || drivers(:verstappen),
        constructor: constructors(:red_bull),
        position: i + 1
      )
    end

    # Should return early without calling the API
    QualifyingSyncJob.new.perform(race_id: race.id)
  end
end
