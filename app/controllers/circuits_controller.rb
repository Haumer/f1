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
        @circuit = Circuit.find(params[:id])
        @races = @circuit.races.includes(:season, race_results: [:driver, :constructor]).order(date: :desc)

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

        # Record Elo at circuit
        new_elo_col = Setting.elo_column(:new_elo).to_sym
        @record_elo_rr = all_results.compact.max_by { |rr| rr.send(new_elo_col) || 0 }

        # Circuit kings
        @circuit_kings = DriverBadge.where("key = ?", "circuit_king_#{@circuit.id}")
                                    .includes(:driver).order(Arel.sql("CASE tier WHEN 'gold' THEN 0 WHEN 'silver' THEN 1 WHEN 'bronze' THEN 2 ELSE 3 END"))
    end
end
