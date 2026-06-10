# Rebuilds the cumulative driver standings for one race in a season.
# Folds in every prior race's main + sprint points, applies countback
# tiebreaking (most P1s, then most P2s, …), and writes a fresh
# DriverStanding row per driver for the target race.
#
# Extracted from UpdateRaceResult so the standings math can be tested
# and reused without dragging the whole network-touching parent in.
class ComputeSeasonStandings
  def initialize(race:)
    @race = race
  end

  def call
    season = @race.season

    cumulative_points = Hash.new(0.0)
    cumulative_wins   = Hash.new(0)
    # Countback: P1 count, P2 count, … P20 count per driver, for ties.
    position_counts = Hash.new { |h, k| h[k] = Hash.new(0) }

    completed_races(season).each do |r|
      RaceResult.where(race: r).each do |rr|
        cumulative_points[rr.driver_id] += rr.points.to_f
        cumulative_wins[rr.driver_id]   += 1 if rr.position_order == 1
        position_counts[rr.driver_id][rr.position_order] += 1 if rr.position_order.present?
      end
      RaceResult.sprint.where(race: r).each do |rr|
        cumulative_points[rr.driver_id] += rr.points.to_f
      end
    end

    sorted = cumulative_points.sort_by do |did, pts|
      countback = (1..20).map { |pos| -position_counts[did][pos] }
      [-pts, *countback]
    end

    sorted.each_with_index do |(driver_id, points), idx|
      ds = DriverStanding.find_or_initialize_by(race: @race, driver_id: driver_id)
      ds.update!(
        position: idx + 1,
        points: points,
        wins: cumulative_wins[driver_id]
      )
      UpdateDriverStanding.new(driver: Driver.find(driver_id), season: season).update
    end

    sorted.size
  end

  private

  def completed_races(season)
    season.races
          .left_joins(:race_results)
          .joins("LEFT JOIN race_results sprint_rr ON sprint_rr.race_id = races.id AND sprint_rr.result_type = 'sprint'")
          .where("races.round <= ?", @race.round)
          .where("race_results.id IS NOT NULL OR sprint_rr.id IS NOT NULL")
          .distinct
          .order(:round)
  end
end
