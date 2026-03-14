require "test_helper"

class SprintResultsTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:season_2026)
    @bahrain = races(:bahrain_2026)
    @melbourne = races(:melbourne_2026)
    @verstappen = drivers(:verstappen)
    @norris = drivers(:norris)
    @leclerc = drivers(:leclerc)
    @piastri = drivers(:piastri)
  end

  # ═══════════════════════════════════════
  # DEFAULT SCOPE PROTECTION
  # ═══════════════════════════════════════

  test "default scope only returns race results" do
    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 1, points: 8)

    assert_equal 4, @bahrain.race_results.count
    assert @bahrain.race_results.all? { |rr| rr.result_type == "race" }
  end

  test "sprint scope returns only sprint results" do
    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 1, points: 8)
    create_sprint_result(@bahrain, @norris, constructors(:mclaren), position_order: 2, points: 7)

    sprints = RaceResult.sprint.where(race: @bahrain)
    assert_equal 2, sprints.count
    assert sprints.all? { |rr| rr.result_type == "sprint" }
  end

  test "all_result_types scope returns both race and sprint" do
    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 1, points: 8)

    all = RaceResult.all_result_types.where(race: @bahrain)
    assert_equal 5, all.count
  end

  test "race.sprint_results association returns only sprints" do
    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 1, points: 8)
    create_sprint_result(@bahrain, @norris, constructors(:mclaren), position_order: 2, points: 7)

    assert_equal 2, @bahrain.sprint_results.count
    assert @bahrain.sprint_results.all? { |rr| rr.result_type == "sprint" }
  end

  test "existing queries on RaceResult are not affected by sprint results" do
    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 1, points: 8)

    results = RaceResult.where(race: @bahrain)
    assert results.none? { |rr| rr.result_type == "sprint" }
    assert_equal 4, results.count
  end

  # ═══════════════════════════════════════
  # ELO ISOLATION
  # ═══════════════════════════════════════

  test "sprint results do not affect elo computation" do
    @bahrain.race_results.update_all(old_elo_v2: nil, new_elo_v2: nil)
    @verstappen.update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    @norris.update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    @leclerc.update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    @piastri.update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)

    # Sprint results with REVERSED positions
    create_sprint_result(@bahrain, @piastri, constructors(:mclaren), position_order: 1, points: 8)
    create_sprint_result(@bahrain, @leclerc, constructors(:ferrari), position_order: 2, points: 7)
    create_sprint_result(@bahrain, @norris, constructors(:mclaren), position_order: 3, points: 6)
    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 4, points: 5)

    EloRatingV2.process_race(@bahrain)

    ver = race_results(:bahrain_2026_verstappen).reload
    assert ver.new_elo_v2 > ver.old_elo_v2, "Verstappen won the race, should gain Elo regardless of sprint P4"

    pia = race_results(:bahrain_2026_piastri).reload
    assert pia.new_elo_v2 < pia.old_elo_v2, "Piastri was P4 in race, should lose Elo regardless of sprint P1"
  end

  test "sprint results never get elo values set" do
    @bahrain.race_results.update_all(old_elo_v2: nil, new_elo_v2: nil)
    @verstappen.update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    @norris.update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    @leclerc.update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    @piastri.update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)

    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 1, points: 8)

    EloRatingV2.process_race(@bahrain)

    sprint_rr = RaceResult.sprint.find_by(race: @bahrain, driver: @verstappen)
    assert_nil sprint_rr.old_elo_v2
    assert_nil sprint_rr.new_elo_v2
  end

  test "elo changes are zero-sum with sprint results present" do
    @bahrain.race_results.update_all(old_elo_v2: nil, new_elo_v2: nil)
    @verstappen.update_columns(elo_v2: 2100.0, peak_elo_v2: 2100.0)
    @norris.update_columns(elo_v2: 2000.0, peak_elo_v2: 2000.0)
    @leclerc.update_columns(elo_v2: 1950.0, peak_elo_v2: 1950.0)
    @piastri.update_columns(elo_v2: 1900.0, peak_elo_v2: 1900.0)

    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 1, points: 8)
    create_sprint_result(@bahrain, @norris, constructors(:mclaren), position_order: 2, points: 7)

    EloRatingV2.process_race(@bahrain)

    diffs = @bahrain.race_results.reload.map { |rr| rr.new_elo_v2 - rr.old_elo_v2 }
    assert_in_delta 0.0, diffs.sum, 0.01, "Elo changes must be zero-sum even with sprints present"
  end

  # ═══════════════════════════════════════
  # STANDINGS INCLUDE SPRINT POINTS
  # ═══════════════════════════════════════

  test "create_standings_from_results includes sprint points in cumulative totals" do
    @bahrain.update_columns(sprint_time: "11:00:00Z")

    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 1, points: 8)
    create_sprint_result(@bahrain, @norris, constructors(:mclaren), position_order: 2, points: 7)
    create_sprint_result(@bahrain, @leclerc, constructors(:ferrari), position_order: 3, points: 6)
    create_sprint_result(@bahrain, @piastri, constructors(:mclaren), position_order: 4, points: 5)

    DriverStanding.where(race: @bahrain).delete_all

    updater = UpdateRaceResult.new(race: @bahrain)
    updater.send(:create_standings_from_results)

    standings = DriverStanding.where(race: @bahrain).index_by(&:driver_id)

    assert_equal 33.0, standings[@verstappen.id].points, "25 race + 8 sprint = 33"
    assert_equal 25.0, standings[@norris.id].points, "18 race + 7 sprint = 25"
    assert_equal 21.0, standings[@leclerc.id].points, "15 race + 6 sprint = 21"
    assert_equal 17.0, standings[@piastri.id].points, "12 race + 5 sprint = 17"
  end

  test "create_standings_from_results counts wins from race only not sprint" do
    @bahrain.update_columns(sprint_time: "11:00:00Z")

    create_sprint_result(@bahrain, @piastri, constructors(:mclaren), position_order: 1, points: 8)
    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 2, points: 7)

    DriverStanding.where(race: @bahrain).delete_all
    updater = UpdateRaceResult.new(race: @bahrain)
    updater.send(:create_standings_from_results)

    standings = DriverStanding.where(race: @bahrain).index_by(&:driver_id)
    assert_equal 1, standings[@verstappen.id].wins, "Only race wins count"
    assert_equal 0, standings[@piastri.id].wins, "Sprint wins do not count"
  end

  test "create_standings_from_results without sprint results still works" do
    DriverStanding.where(race: @bahrain).delete_all
    updater = UpdateRaceResult.new(race: @bahrain)
    updater.send(:create_standings_from_results)

    standings = DriverStanding.where(race: @bahrain).index_by(&:driver_id)
    assert_equal 25.0, standings[@verstappen.id].points
    assert_equal 18.0, standings[@norris.id].points
  end

  test "standings correctly accumulate sprint points across multiple races" do
    # Set bahrain as sprint race and create sprint results
    @bahrain.update_columns(sprint_time: "11:00:00Z")
    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 1, points: 8)
    create_sprint_result(@bahrain, @norris, constructors(:mclaren), position_order: 2, points: 7)

    # Create race results for melbourne too
    RaceResult.create!(race: @melbourne, driver: @verstappen, constructor: constructors(:red_bull),
                       status: statuses(:finished), position: 2, position_order: 2, points: 18, laps: 58)
    RaceResult.create!(race: @melbourne, driver: @norris, constructor: constructors(:mclaren),
                       status: statuses(:finished), position: 1, position_order: 1, points: 25, laps: 58)

    DriverStanding.where(race: @melbourne).delete_all
    updater = UpdateRaceResult.new(race: @melbourne)
    updater.send(:create_standings_from_results)

    standings = DriverStanding.where(race: @melbourne).index_by(&:driver_id)

    # Verstappen: R1 race 25 + R1 sprint 8 + R2 race 18 = 51
    assert_equal 51.0, standings[@verstappen.id].points, "Should accumulate sprint + race across rounds"
    # Norris: R1 race 18 + R1 sprint 7 + R2 race 25 = 50
    assert_equal 50.0, standings[@norris.id].points, "Should accumulate sprint + race across rounds"
  end

  # ═══════════════════════════════════════
  # RACE MODEL
  # ═══════════════════════════════════════

  test "sprint? returns true when sprint_time is set" do
    @bahrain.update_columns(sprint_time: "11:00:00Z")
    assert @bahrain.sprint?
  end

  test "sprint? returns false when sprint_time is nil" do
    @bahrain.update_columns(sprint_time: nil)
    assert_not @bahrain.sprint?
  end

  test "has_sprint_results? returns true when sprint results exist" do
    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 1, points: 8)
    assert @bahrain.has_sprint_results?
  end

  test "has_sprint_results? returns false when no sprint results" do
    assert_not @bahrain.has_sprint_results?
  end

  test "session_schedule returns sprint format for sprint weekends" do
    @bahrain.update_columns(sprint_time: "11:00:00Z", sprint_quali_time: "15:00:00Z")
    keys = @bahrain.session_schedule.map { |s| s[:key] }
    assert_equal [:fp1, :sprint_quali, :sprint, :quali, :race], keys
  end

  test "session_schedule returns normal format for non-sprint weekends" do
    @bahrain.update_columns(sprint_time: nil, sprint_quali_time: nil)
    keys = @bahrain.session_schedule.map { |s| s[:key] }
    assert_equal [:fp1, :fp2, :fp3, :quali, :race], keys
  end

  # ═══════════════════════════════════════
  # UNIQUE INDEX — race + driver + result_type
  # ═══════════════════════════════════════

  test "same driver can have both race and sprint result for same race" do
    sprint_rr = create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 1, points: 8)
    race_rr = race_results(:bahrain_2026_verstappen)

    assert race_rr.persisted?
    assert sprint_rr.persisted?
    assert_equal "race", race_rr.result_type
    assert_equal "sprint", sprint_rr.result_type
  end

  # ═══════════════════════════════════════
  # SEASON SYNC — STALE DETECTION
  # ═══════════════════════════════════════

  test "session_data_stale? returns true when qualifying missing on quali day" do
    travel_to Date.new(2026, 3, 7) do
      QualifyingResult.where(race: @bahrain).delete_all
      assert SeasonSync.send(:session_data_stale?, @season)
    end
  end

  test "session_data_stale? returns false when qualifying exists" do
    travel_to Date.new(2026, 3, 7) do
      assert_not SeasonSync.send(:session_data_stale?, @season)
    end
  end

  test "session_data_stale? returns true when sprint missing on sprint day" do
    @bahrain.update_columns(sprint_time: "11:00:00Z")
    travel_to Date.new(2026, 3, 7) do
      assert SeasonSync.send(:session_data_stale?, @season)
    end
  end

  test "session_data_stale? returns false when not a sprint weekend" do
    @bahrain.update_columns(sprint_time: nil)
    travel_to Date.new(2026, 3, 7) do
      assert_not SeasonSync.send(:session_data_stale?, @season)
    end
  end

  test "session_data_stale? returns false outside race weekend" do
    travel_to Date.new(2026, 2, 1) do
      assert_not SeasonSync.send(:session_data_stale?, @season)
    end
  end

  test "session_data_stale? returns false when sprint results exist" do
    @bahrain.update_columns(sprint_time: "11:00:00Z")
    create_sprint_result(@bahrain, @verstappen, constructors(:red_bull), position_order: 1, points: 8)
    travel_to Date.new(2026, 3, 7) do
      assert_not SeasonSync.send(:session_data_stale?, @season)
    end
  end

  private

  def create_sprint_result(race, driver, constructor, position_order:, points:)
    RaceResult.unscoped.create!(
      race: race,
      driver: driver,
      constructor: constructor,
      status: statuses(:finished),
      result_type: "sprint",
      position: position_order,
      position_order: position_order,
      points: points,
      laps: 20
    )
  end
end
