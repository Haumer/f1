class CircuitsController < ApplicationController
  def index
    current_season = Season.find_by(year: Setting.effective_today.year.to_s) ||
             Season.sorted_by_year.first
    @calendar_races = current_season&.races
              &.includes(:circuit, race_results: [:driver, :constructor])
              &.order(:date) || Race.none
    @calendar_circuit_ids = @calendar_races.map(&:circuit_id)
    @season_year = current_season&.year

    @circuits = Circuit.left_joins(:races)
              .select("circuits.*, COUNT(races.id) as races_count")
              .group("circuits.id")
              .having("COUNT(races.id) > 0")
              .order("races_count DESC, circuits.name ASC")
  end

  def show
    @circuit = Circuit.find_by!(circuit_ref: params[:id])
    set_circuit_accent(@circuit)
    @races = @circuit.races.includes(:season, race_results: [driver: :countries, constructor: [], status: []]).order(date: :desc)

    # Circuit stats
    @first_race_year = @races.last&.season&.year
    @latest_race_year = @races.first&.season&.year
    @highest_avg_elo_race = @races.select { |r| r.average_elo.present? }.max_by(&:average_elo)

    # Most successful driver (most wins at this circuit)
    all_results = @races.flat_map(&:race_results)
    wins_by_driver = all_results.select { |rr| rr.position_order == 1 }.group_by(&:driver)
    if wins_by_driver.any?
      @most_successful_driver, @most_successful_wins = wins_by_driver.max_by { |_, rrs| rrs.size }
    end

    # Top winners at this circuit (for expanded stats)
    @circuit_winners = wins_by_driver
      .map { |driver, rrs| { driver: driver, wins: rrs.size, years: rrs.map { |rr| rr.race.season&.year }.compact } }
      .sort_by { |w| -w[:wins] }
      .first(10)

    # Most successful constructor at this circuit
    wins_by_constructor = all_results.select { |rr| rr.position_order == 1 && rr.constructor }.group_by(&:constructor)
    if wins_by_constructor.any?
      @most_successful_constructor, @constructor_wins = wins_by_constructor.max_by { |_, rrs| rrs.size }
    end

    # Record Elo at circuit
    new_elo_col = Setting.elo_column(:new_elo).to_sym
    @record_elo_rr = all_results.compact.max_by { |rr| rr.send(new_elo_col) || 0 }

    # Circuit kings
    @circuit_kings = DriverBadge.circuit_kings_for(@circuit.id)

    # Podium data per race for the expanded race history
    @podiums_by_race = @races.each_with_object({}) do |race, hash|
      hash[race.id] = race.race_results
        .select { |rr| rr.position_order && rr.position_order <= 3 }
        .sort_by(&:position_order)
    end
  end
end
