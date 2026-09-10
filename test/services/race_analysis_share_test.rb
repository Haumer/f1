require "test_helper"
require_relative "../support/race_expectation_history"

class RaceAnalysisShareTest < ActiveSupport::TestCase
  include RaceExpectationHistory

  test "public payload matches the report and excludes DNFs" do
    RaceExpectations::Dataset.stub(:before, expectation_history) do
      analysis = RaceAnalysis.new(race: races(:bahrain_2026))
      card = RaceAnalysisShare.new(analysis)
      assert_equal analysis.expectations.top_three.map { |entry| entry.driver.fullname }, card.payload[:top].pluck(:name)
      assert_equal analysis.expectations.flop_three.map { |entry| entry.driver.fullname }, card.payload[:flop].pluck(:name)
      assert_equal 3, card.payload[:assessed]
      assert_equal PublicSite.url("/races/#{analysis.race.id}#race-analysis"), card.url
      assert_includes card.description, "3/4 entrants assessed"
      assert_not_includes card.payload.to_json, drivers(:piastri).fullname
    end
  end

  test "result corrections change the image fingerprint without touching the race" do
    RaceExpectations::Dataset.stub(:before, expectation_history) do
      race = races(:bahrain_2026)
      before = RaceAnalysisShare.new(RaceAnalysis.new(race: race)).fingerprint
      updated_at = race.updated_at
      race_results(:bahrain_2026_norris).update_columns(position_order: 4)
      after = RaceAnalysisShare.new(RaceAnalysis.new(race: race.reload)).fingerprint
      assert_not_equal before, after
      assert_equal updated_at, race.updated_at
    end
  end

  test "missing estimates are described honestly" do
    card = RaceAnalysisShare.new(RaceAnalysis.new(race: races(:bahrain_2026)))
    assert_empty card.payload[:top]
    assert_empty card.payload[:flop]
    assert_includes card.description, "unavailable"
  end

  test "a field with only retirements has no rankings even when estimates exist" do
    RaceExpectations::Dataset.stub(:before, expectation_history) do
      race = races(:bahrain_2026)
      race.race_results.update_all(status_id: race_results(:bahrain_2026_piastri).status_id)
      analysis = RaceAnalysis.new(race: race)
      card = RaceAnalysisShare.new(analysis)
      assert_equal 4, analysis.expectations.predicted_count
      assert_equal 0, card.payload[:assessed]
      assert_empty card.payload[:top]
      assert_empty card.payload[:flop]
      assert_includes card.description, "DNFs are not assessed"
    end
  end
end
