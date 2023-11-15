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
            first_places = data[:cumulative_race_results].count {|rr| rr.position == 1}
            second_places = data[:cumulative_race_results].count {|rr| rr.position == 2}
            third_places = data[:cumulative_race_results].count {|rr| rr.position == 3}
            podiums = third_places + second_places + first_places
            data[:driver_standing].update(second_places: second_places, third_places: third_places, podiums: podiums)
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