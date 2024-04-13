class UpdateSeason
    ENDPOINT = "https://ergast.com/api/f1/"
    def initialize(year:)
        @year = year
        fetch_season
        set_season_schedule
    end

    def fetch_season
        @season_data = JSON.parse(URI.open("#{ENDPOINT}#{@year}.json").read)
    end

    def set_season_schedule
        @season_data["MRData"]["RaceTable"]["Races"].map.with_index do |race, index|
            last_race = @season_data["MRData"]["RaceTable"]["Races"].length == index + 1
            season = Season.find_or_create_by(year: race["season"])
            {
                round: race["round"],
                year: race["season"],
                date: race["date"].to_date,
                circuit: Circuit.find_by(circuit_ref: race["Circuit"]["circuitId"]),
                url: race["url"],
                season: season,
                season_end: last_race
            }
        end
    end
end