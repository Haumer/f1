class UpdateDriverStanding
    def initialize(driver:, season:)
        @driver = driver
        @season = season
        @races = season.races.sorted
        @driver_standings = driver.driver_standings.where(race_id: @races.pluck(:id))
        @race_results = driver.race_results.where(race_id: @races.pluck(:id))
    end

    def update
        zip.each do |race, data|
            first_places = data[:cumulative_race_results].count {|rr| rr.position_order == 1}
            second_places = data[:cumulative_race_results].count {|rr| rr.position_order == 2}
            third_places = data[:cumulative_race_results].count {|rr| rr.position_order == 3}
            fourth_places = data[:cumulative_race_results].count {|rr| rr.position_order == 4}
            fifth_places = data[:cumulative_race_results].count {|rr| rr.position_order == 5}
            sixth_places = data[:cumulative_race_results].count {|rr| rr.position_order == 6}
            seventh_places = data[:cumulative_race_results].count {|rr| rr.position_order == 7}
            eighth_places = data[:cumulative_race_results].count {|rr| rr.position_order == 8}
            nineth_places = data[:cumulative_race_results].count {|rr| rr.position_order == 9}
            tenth_places = data[:cumulative_race_results].count {|rr| rr.position_order == 10}
            outside_of_top_ten = data[:cumulative_race_results].count {|rr| rr.position_order > 10}
            podiums = third_places + second_places + first_places
            
            crash_races = data[:cumulative_race_results].count {|rr| rr.status.accident?}
            technichal_failures_races = data[:cumulative_race_results].count {|rr| rr.status.technical?}
            disqualified_races = data[:cumulative_race_results].count {|rr| rr.status.disqualified?}
            lapped_races = data[:cumulative_race_results].count {|rr| rr.status.lapped?}
            finished_races = data[:cumulative_race_results].count {|rr| rr.status.finished?}

            data[:driver_standing].update(
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