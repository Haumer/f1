class UpdateDriverCareer
    attr_reader :career_attributes

    def initialize(driver:)
        @driver = driver
        @career_attributes = {
            podiums: 0, 
            wins: 0, 
            second_places: 0, 
            third_places: 0, 
            fourth_places: 0, 
            fifth_places: 0, 
            sixth_places: 0, 
            seventh_places: 0, 
            eighth_places: 0, 
            nineth_places: 0, 
            tenth_places: 0, 
            outside_of_top_ten: 0, 
            crash_races: 0, 
            lapped_races: 0, 
            technichal_failures_races: 0, 
            disqualified_races: 0, 
            fastest_laps: 0,
            finished_races: 0,
        }
        set_attributes
    end

    def set_attributes
        results = @driver.race_results.includes(:status, :race).to_a
        # Exclude DNS (did not qualify / did not start) from race count
        started = results.reject { |rr| rr.status.did_not_start? }
        @career_attributes[:number_of_races] = started.size
        started.each do |race_result|
            positions(race_result)
            races(race_result)
        end
        @career_attributes[:podiums] = @career_attributes[:wins] + @career_attributes[:second_places] + @career_attributes[:third_places]

        # Update first/last race dates from actual race results
        race_dates = results.filter_map { |rr| rr.race.date }
        if race_dates.any?
            @career_attributes[:first_race_date] = race_dates.min
            @career_attributes[:last_race_date] = race_dates.max
        end

        self
    end

    def update
        @driver.update(@career_attributes)
    end

    def races(race_result)
        if race_result.status.finished? || race_result.status.lapped?
            @career_attributes[:finished_races] += 1
            @career_attributes[:lapped_races] += 1 if race_result.status.lapped?
        elsif race_result.status.disqualified?
            @career_attributes[:disqualified_races] += 1
        elsif race_result.status.accident?
            @career_attributes[:crash_races] += 1
        elsif race_result.status.technical?
            @career_attributes[:technichal_failures_races] += 1
        elsif race_result.status.retired? || race_result.status.health?
            @career_attributes[:crash_races] += 1
        end
    end

    def positions(race_result)  
        case race_result.position_order
        when 1 then @career_attributes[:wins] += 1
        when 2 then @career_attributes[:second_places] += 1
        when 3 then @career_attributes[:third_places] += 1
        when 4 then @career_attributes[:fourth_places] += 1
        when 5 then @career_attributes[:fifth_places] += 1
        when 6 then @career_attributes[:sixth_places] += 1
        when 7 then @career_attributes[:seventh_places] += 1
        when 8 then @career_attributes[:eighth_places] += 1
        when 9 then @career_attributes[:nineth_places] += 1
        when 10 then @career_attributes[:tenth_places] += 1
        else
            @career_attributes[:outside_of_top_ten] += 1
        end
    end
end