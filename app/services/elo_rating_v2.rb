class EloRatingV2
    STARTING_ELO = 2000.0
    BASE_K = 48
    REGRESSION_FACTOR = 0.03
    REFERENCE_RACES = 12.0
    SCALE = 400.0

    # Run full historical simulation from scratch
    def self.simulate_all!
        races = Race.includes(race_results: :driver).order(:date, :round).to_a
        races_per_year = Race.joins(:race_results).distinct.group(:year).count

        elo = {}
        peak = {}
        prev_year = nil

        # Collect all updates for batch persistence
        race_result_updates = []
        driver_updates = {}

        races.each do |race|
            year = race.year

            # Season-end regression
            if prev_year && year != prev_year
                elo.each { |did, e| elo[did] = e * (1 - REGRESSION_FACTOR) + STARTING_ELO * REGRESSION_FACTOR }
            end
            prev_year = year

            season_races = races_per_year[year] || REFERENCE_RACES.to_i
            results = race.race_results.select { |rr| rr.position_order.present? }.sort_by(&:position_order)
            next if results.size < 2

            n = results.size
            k_pair = BASE_K * (REFERENCE_RACES / season_races.to_f) / Math.sqrt(n - 1)

            results.each { |rr| elo[rr.driver_id] ||= STARTING_ELO }

            adjustments = Hash.new(0.0)
            results.combination(2) do |a, b|
                ra = elo[a.driver_id]
                rb = elo[b.driver_id]
                ea = 1.0 / (1 + 10**((rb - ra) / SCALE))
                adjustments[a.driver_id] += k_pair * (1.0 - ea)
                adjustments[b.driver_id] += k_pair * (0.0 - (1.0 - ea))
            end

            adjustments.each do |did, adj|
                old_elo = elo[did]
                elo[did] += adj
                peak[did] = [peak[did] || 0, elo[did]].max
                # Find the race_result for this driver
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

        # Use total scheduled races (not just those with results) for proper K factor scaling
        season_races = Race.where(year: race.year).count
        n = results.size
        k_pair = BASE_K * (REFERENCE_RACES / season_races.to_f) / Math.sqrt(n - 1)

        adjustments = Hash.new(0.0)
        results.combination(2) do |a, b|
            ra = a.driver.elo_v2 || STARTING_ELO
            rb = b.driver.elo_v2 || STARTING_ELO
            ea = 1.0 / (1 + 10**((rb - ra) / SCALE))
            adjustments[a.driver_id] += k_pair * (1.0 - ea)
            adjustments[b.driver_id] += k_pair * (0.0 - (1.0 - ea))
        end

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
