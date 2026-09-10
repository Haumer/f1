require "test_helper"

class RaceAnalysisTest < ActiveSupport::TestCase
  setup do
    @race = races(:bahrain_2026)
  end

  test "uses race snapshots rather than current or future driver ratings" do
    drivers(:verstappen).update_columns(elo_v2: 1000)
    drivers(:piastri).update_columns(elo_v2: 4000)

    report = RaceAnalysis.new(race: @race)
    assert report.seeded?
    assert_equal 1, row_for(report, :verstappen).seed
    assert_equal 4, row_for(report, :piastri).seed
    assert_equal 20, row_for(report, :verstappen).elo_change
    assert_equal 1000, drivers(:verstappen).reload.elo_v2
  end

  test "equal ratings share a seed and a report reflects corrected records" do
    race_results(:bahrain_2026_norris).update!(old_elo_v2: 2380)
    report = RaceAnalysis.new(race: @race)
    assert_equal 1.5, row_for(report, :norris).seed
    assert_equal 1.5, row_for(report, :verstappen).seed
    assert_equal 3, row_for(report, :leclerc).seed

    race_results(:bahrain_2026_norris).update!(old_elo_v2: 2500)
    assert_equal 2, row_for(RaceAnalysis.new(race: @race), :verstappen).seed
  end

  test "an equal-rated opening field uses midpoint ranks not a field of first seeds" do
    @race.race_results.update_all(old_elo_v2: 2000)
    report = RaceAnalysis.new(race: @race)
    assert report.rows.all? { |row| row.seed == 2.5 }
    assert_equal 1.5, row_for(report, :verstappen).seed_change
    assert_equal(-0.5, row_for(report, :leclerc).seed_change)
  end

  test "missing snapshots are not zero and disable full field seeding" do
    race_results(:bahrain_2026_norris).update!(old_elo_v2: nil, new_elo_v2: nil)
    report = RaceAnalysis.new(race: @race)

    assert_equal 3, report.coverage[:elo]
    assert_nil row_for(report, :norris).elo_change
    assert_not report.seeded?
    assert_empty report.comparison_rows
    assert_equal 3, report.highlights.size
  end

  test "all zero changes are not announced as gains or losses" do
    @race.race_results.update_all("new_elo_v2 = old_elo_v2")
    report = RaceAnalysis.new(race: @race)
    assert_equal ["Largest grid-to-finish gain"], report.highlights.map { |card| card[:label] }
  end

  test "retirements do not become place losses or clean teammate gaps" do
    report = RaceAnalysis.new(race: @race)
    piastri = row_for(report, :piastri)
    assert_equal "DNF", piastri.display_position
    assert_nil piastri.grid_change
    assert_nil piastri.seed_change
    assert_equal(-10, piastri.elo_change)
    assert_not_includes report.comparison_rows, piastri
    assert_nil report.teammates.first[:gap]
    assert_match "Retired", report.highlights.find { |card| card[:label] == "Largest Elo loss" }[:detail]
  end

  test "lapped finishers are comparable and missing or zero grid slots are not" do
    race_results(:bahrain_2026_norris).update!(status: statuses(:lapped_one), grid: 0)
    race_results(:bahrain_2026_leclerc).update!(grid: nil)
    report = RaceAnalysis.new(race: @race)

    assert_equal 2, report.coverage[:grid]
    assert row_for(report, :norris).classified?
    assert_equal 0, row_for(report, :norris).seed_change
    assert_nil row_for(report, :norris).grid_change
    assert_nil row_for(report, :leclerc).grid_change
  end

  test "missing result order cannot produce a seeded comparison" do
    race_results(:bahrain_2026_norris).update!(position_order: nil)
    report = RaceAnalysis.new(race: @race)
    assert_not report.seeded?
    assert_nil row_for(report, :norris).grid_change
  end

  test "sprint results are not included and qualifying is limited to race entrants" do
    source = race_results(:bahrain_2026_verstappen)
    sprint = source.dup
    sprint.result_type = "sprint"
    sprint.save!
    report = RaceAnalysis.new(race: @race)
    assert_equal 4, report.rows.size
    assert_equal 4, report.coverage[:results]
  end

  test "qualifying compares the latest valid shared segment not Q1 against Q3" do
    @race.qualifying_results.destroy_all
    QualifyingResult.create!(race: @race, driver: drivers(:norris), position: 2,
                             q1: "1:30.000", q2: "1:29.500", q3: "1:28.000")
    QualifyingResult.create!(race: @race, driver: drivers(:piastri), position: 11,
                             q1: "1:30.200", q2: "1:29.800")
    report = RaceAnalysis.new(race: @race)
    comparison = report.teammates.first[:qualifying]
    assert_equal 2, report.coverage[:qualifying]
    assert_equal "Q2", comparison[:segment]
    assert_in_delta 0.3, comparison[:gap]
    assert_equal drivers(:norris), comparison[:faster].driver
  end

  test "malformed qualifying times are unavailable not zero" do
    @race.qualifying_results.destroy_all
    QualifyingResult.create!(race: @race, driver: drivers(:norris), position: 2, q1: "DNS", q2: "1:99.000")
    QualifyingResult.create!(race: @race, driver: drivers(:piastri), position: 11, q1: "1:30.200", q2: "1:29.800")
    assert_nil RaceAnalysis.new(race: @race).teammates.first[:qualifying]
  end

  test "championship never compares to the previous season" do
    report = RaceAnalysis.new(race: @race)
    assert_nil report.previous_round
    assert report.championship.all? { |entry| entry[:movement].nil? }
  end

  test "championship movement uses the preceding round not future standings" do
    race = races(:melbourne_2026)
    DriverStanding.create!(race: race, driver: drivers(:norris), position: 1, points: 43)
    report = RaceAnalysis.new(race: race)
    assert_equal @race, report.previous_round
    assert_equal 1, report.championship.first[:movement]

    @race.driver_standings.destroy_all
    assert_nil RaceAnalysis.new(race: race).championship.first[:movement]
  end

  test "teammates come from race constructor not current season assignments" do
    race_results(:bahrain_2026_piastri).update!(constructor: constructors(:ferrari), status: statuses(:finished))
    report = RaceAnalysis.new(race: @race)
    assert_equal constructors(:ferrari), report.teammates.first[:constructor]
    assert_equal 1, report.teammates.first[:gap]
  end

  test "fantasy uses only scored picks for this race and returns no identities" do
    RacePick.where(race: @race).delete_all
    RacePick.create!(race: @race, user: users(:codex), picks: [], score: 0)
    report = RaceAnalysis.new(race: @race)
    assert_equal({ players: 1, best: 0, average: 0.0 }, report.fantasy)
    assert_equal 0, RaceAnalysis.new(race: races(:melbourne_2025)).fantasy[:players]
  end

  test "race without results has no debrief facts" do
    report = RaceAnalysis.new(race: races(:melbourne_2026))
    assert_not report.available?
    assert_not report.seeded?
    assert_empty report.highlights
    assert_empty report.teammates
  end

  private

  def row_for(report, name)
    report.rows.find { |row| row.driver == drivers(name) }
  end
end
