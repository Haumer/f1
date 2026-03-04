class UpdateDriverStanding
    def initialize(driver:, season:)
        @driver = driver
        @season = season
        @races = season.races.sorted
        race_ids = @races.pluck(:id)
        @driver_standings = driver.driver_standings.where(race_id: race_ids)
        @race_results = driver.race_results.where(race_id: race_ids).includes(:status)
    end

    def update
        zip.each do |race, data|
            results = data[:cumulative_race_results]

            position_counts = results.group_by(&:position_order)
            first_places = position_counts[1]&.size || 0
            second_places = position_counts[2]&.size || 0
            third_places = position_counts[3]&.size || 0
            fourth_places = position_counts[4]&.size || 0
            fifth_places = position_counts[5]&.size || 0
            sixth_places = position_counts[6]&.size || 0
            seventh_places = position_counts[7]&.size || 0
            eighth_places = position_counts[8]&.size || 0
            nineth_places = position_counts[9]&.size || 0
            tenth_places = position_counts[10]&.size || 0
            outside_of_top_ten = results.count { |rr| rr.position_order > 10 }
            podiums = first_places + second_places + third_places

            crash_races = results.count { |rr| rr.status&.accident? }
            technichal_failures_races = results.count { |rr| rr.status&.technical? }
            disqualified_races = results.count { |rr| rr.status&.disqualified? }
            lapped_races = results.count { |rr| rr.status&.lapped? }
            finished_races = results.count { |rr| rr.status&.finished? }

            data[:driver_standing].update(
                wins: first_places,
                second_places: second_places,
                third_places: third_places,
                fourth_places: fourth_places,
                fifth_places: fifth_places,
                sixth_places: sixth_places,
                seventh_places: seventh_places,
                eighth_places: eighth_places,
                nineth_places: nineth_places,
                tenth_places: tenth_places,
                outside_of_top_ten: outside_of_top_ten,
                crash_races: crash_races,
                technichal_failures_races: technichal_failures_races,
                disqualified_races: disqualified_races,
                lapped_races: lapped_races,
                finished_races: finished_races,
                podiums: podiums,
            )
        end
        @driver_standings
    end

    def zip
        data = {}
        @races.each_with_index do |race, index|
            next unless race.driver_standings.present?

            driver_standing = @driver_standings.find_by(race: race)
            race_results = @race_results.where(race: @races[0..index])

            next unless driver_standing.present? && race_results.present?

            data[race.id] = {
                driver_standing: driver_standing,
                cumulative_race_results: race_results
            }
        end

        return data
    end
end
