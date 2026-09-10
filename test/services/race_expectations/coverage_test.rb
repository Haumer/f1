require "test_helper"
require_relative "../../support/race_expectation_history"

class RaceExpectations::CoverageTest < ActiveSupport::TestCase
  include RaceExpectationHistory

  test "coverage distinguishes complete partial and absent estimates without fitting" do
    RaceExpectations::Backtest.stub(:enough?, true) do
      report = RaceExpectations::Coverage.call(before: Date.new(2026, 4, 1), year: 2026)
      entry = report[:races].find { |row| row[:race_id] == races(:bahrain_2026).id }
      assert_equal 4, entry[:estimated]
      assert_equal 3, entry[:assessed]
      assert_empty entry[:missing]

      qualifying_results(:nor_bahrain_2026).destroy!
      report = RaceExpectations::Coverage.call(before: Date.new(2026, 4, 1), year: 2026)
      entry = report[:races].find { |row| row[:race_id] == races(:bahrain_2026).id }
      assert_equal 3, entry[:estimated]
      assert_equal ["qualifying"], entry[:missing]

      race_results(:bahrain_2026_verstappen).update!(old_elo_v2: nil)
      report = RaceExpectations::Coverage.call(before: Date.new(2026, 4, 1), year: 2026)
      entry = report[:races].find { |row| row[:race_id] == races(:bahrain_2026).id }
      assert_equal 0, entry[:estimated]
      assert_includes entry[:missing], "pre_race_elo_or_field"
    end
  end

  test "warm-up excludes target and future races" do
    race = races(:bahrain_2026)
    events_seen = []
    check = ->(events) { events_seen.concat(events); false }
    RaceExpectations::Backtest.stub(:enough?, check) do
      report = RaceExpectations::Coverage.call(before: race.date + 1.day, year: 2026)
      assert_equal 0, report[:summary][:estimated_entrants]
      assert_not events_seen.any? { |event| event[:date] >= race.date }
    end
  end
end
