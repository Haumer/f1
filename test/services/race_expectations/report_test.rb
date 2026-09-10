require "test_helper"
require_relative "../../support/race_expectation_history"

class RaceExpectations::ReportTest < ActiveSupport::TestCase
  include RaceExpectationHistory

  test "entire field includes DNFs with expectations but without a performance verdict" do
    report = build_report
    assert_equal 4, report.assessments.size
    assert_equal 4, report.predicted_count
    retired = report.assessments.find { |assessment| assessment.driver == drivers(:piastri) }
    assert retired.expected
    assert_nil retired.difference
    assert_equal "Not assessed", retired.verdict
    assert_includes retired.reason, "DNF"
  end

  test "missing qualifying and invalid positions stay visible not guessed from grid" do
    qualifying_results(:nor_bahrain_2026).destroy!
    qualifying_results(:lec_bahrain_2026).update!(position: 99)
    report = build_report
    assert_equal 4, report.assessments.size
    assert_equal 2, report.predicted_count
    assert_equal 2, report.assessments.count { |assessment| assessment.reason == "Qualifying unavailable" }
  end

  test "starting grid and actual finishing position do not affect the estimate" do
    before = build_report.assessments.find { |assessment| assessment.driver == drivers(:norris) }
    race_results(:bahrain_2026_norris).update!(grid: 15, position_order: 4)
    after = build_report.assessments.find { |assessment| assessment.driver == drivers(:norris) }
    assert_equal before.expected, after.expected
    assert_equal before.difference - 2, after.difference
  end

  test "better qualifying changes the estimate with Elo unchanged" do
    before = build_report.assessments.find { |assessment| assessment.driver == drivers(:norris) }
    qualifying_results(:nor_bahrain_2026).update!(position: 1)
    after = build_report.assessments.find { |assessment| assessment.driver == drivers(:norris) }
    assert_operator after.expected, :<, before.expected
  end

  test "missing rating or insufficient history does not manufacture estimates" do
    race_results(:bahrain_2026_verstappen).update!(old_elo_v2: nil)
    assert_equal 0, build_report.predicted_count
    assert_equal 0, build_report(history: []).predicted_count
  end

  test "range and verdict agree at their displayed boundaries" do
    row = RaceAnalysis.new(race: races(:bahrain_2026)).rows.first
    assessment = RaceExpectations::Report::Assessment.new(row: row, expected: 3.0, low: 1, high: 4, field_size: 4)
    assert_equal "In range", assessment.verdict
    assessment.low = 2
    assert_equal "Above range", assessment.verdict
  end

  test "even a missing actual result cannot change its pre-race expectation" do
    before = build_report.assessments.find { |assessment| assessment.driver == drivers(:norris) }
    race_results(:bahrain_2026_norris).update!(position_order: nil)
    after = build_report.assessments.find { |assessment| assessment.driver == drivers(:norris) }
    assert_equal before.expected, after.expected
    assert_nil after.difference
    assert_equal "Result order unavailable", after.reason
  end

  test "cache invalidates on changed training values even without timestamps" do
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      history = expectation_history
      before = build_report(history: history).profile
      history.first[:samples].each { |sample| sample[:finish] = 0.0 }
      after = build_report(history: history).profile
      assert_not_equal before[:model], after[:model]
    end
  end

  private

  def build_report(history: expectation_history)
    race = races(:bahrain_2026).reload
    RaceExpectations::Report.new(race: race, rows: RaceAnalysis.new(race: race).rows,
      qualifying: race.qualifying_results.index_by(&:driver_id), history: history)
  end
end
