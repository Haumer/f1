class EloRatingV2
    STARTING_ELO = 2000.0
    BASE_K = 48
    REGRESSION_FACTOR = 0.03
    REFERENCE_RACES = 12.0

    # Run full historical simulation from scratch
    def self.simulate_all!
        races = Race.includes(race_results: :driver).order(:date, :round).to_a
        races_per_year = Race.joins(:race_results).distinct.group(:year).count

        elo = {}
        peak = {}
        prev_year = nil

        race_result_updates = []
        driver_updates = {}

        races.each do |race|
            year = race.year

            if prev_year && year != prev_year
                elo.each { |did, e| elo[did] = e * (1 - REGRESSION_FACTOR) + STARTING_ELO * REGRESSION_FACTOR }
            end
            prev_year = year

            season_races = races_per_year[year] || REFERENCE_RACES.to_i
            results = race.race_results.select { |rr| rr.position_order.present? }.sort_by(&:position_order)
            next if results.size < 2

            results.each { |rr| elo[rr.driver_id] ||= STARTING_ELO }

            participants = results.map { |rr| { id: rr.driver_id, elo: elo[rr.driver_id], score: rr.position_order } }
            k_pair = EloMath.compute_k_pair(BASE_K, REFERENCE_RACES, season_races, results.size)
            adjustments = EloMath.pairwise_adjustments(participants, k_pair)

            adjustments.each do |did, adj|
                old_elo = elo[did]
                elo[did] += adj
                peak[did] = [peak[did] || 0, elo[did]].max
                rr = results.find { |r| r.driver_id == did }
                race_result_updates << { id: rr.id, old_elo_v2: old_elo, new_elo_v2: elo[did] }
                driver_updates[did] = { elo_v2: elo[did], peak_elo_v2: peak[did] }
            end
        end

        # Batch persist
        ActiveRecord::Base.transaction do
            race_result_updates.each_slice(500) do |batch|
                batch.each do |update|
                    RaceResult.where(id: update[:id]).update_all(old_elo_v2: update[:old_elo_v2], new_elo_v2: update[:new_elo_v2])
                end
            end

            driver_updates.each do |did, attrs|
                Driver.where(id: did).update_all(attrs)
            end
        end

        { drivers_updated: driver_updates.size, race_results_updated: race_result_updates.size }
    end

    # Process a single race (for incremental updates)
    def self.process_race(race)
        results = race.race_results.includes(:driver)
                      .select { |rr| rr.position_order.present? }
                      .sort_by(&:position_order)
        return if results.size < 2

        season_races = Race.where(year: race.year).count
        participants = results.map { |rr| { id: rr.driver_id, elo: rr.driver.elo_v2 || STARTING_ELO, score: rr.position_order } }
        k_pair = EloMath.compute_k_pair(BASE_K, REFERENCE_RACES, season_races, results.size)
        adjustments = EloMath.pairwise_adjustments(participants, k_pair)

        ActiveRecord::Base.transaction do
            results.each do |rr|
                driver = rr.driver
                old_elo = driver.elo_v2 || STARTING_ELO
                new_elo = old_elo + (adjustments[driver.id] || 0)
                new_peak = [driver.peak_elo_v2 || 0, new_elo].max

                rr.update!(old_elo_v2: old_elo, new_elo_v2: new_elo)
                driver.update!(elo_v2: new_elo, peak_elo_v2: new_peak)
            end
        end
    end

    # Apply season-end regression to all drivers with V2 ratings
    def self.apply_regression!
        Driver.where.not(elo_v2: nil).find_each do |driver|
            regressed = driver.elo_v2 * (1 - REGRESSION_FACTOR) + STARTING_ELO * REGRESSION_FACTOR
            driver.update!(elo_v2: regressed)
        end
    end
end
