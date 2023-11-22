class Driver < ApplicationRecord
    has_many :race_results
    has_many :races, through: :race_results
    has_many :driver_ratings
    has_many :driver_standings
    has_many :driver_countries
    has_many :countries, through: :driver_countries
    has_many :season_drivers
    has_many :seasons, through: :season_drivers
    has_many :constructors, through: :season_drivers

    scope :active, -> { where(active: true) }
    scope :elite, -> { where(skill: 'elite') }
    scope :by_peak_elo, -> { order(peak_elo: :desc) }
    scope :by_first_race_date, -> { order(first_race_date: :asc) }
    scope :by_last_race_date, -> { order(last_race_date: :asc) }

    # https://www.rapidtables.com/web/color/RGB_Color.html
    COLORS = [
        "#800000", # marroon
        "#FF0000", # red
        "#F08080", # light coral
        "#FF8C00", # dark orange
        "#FFD700", # gold
        "#DAA520", # golden rod
        "#EEE8AA", # pale golden rod
        "#BDB76B", # dark khaki
        "#F0E68C", # khaki
        "#808000", # olive
        "#FFFF00", # yellow
        "#9ACD32", # yellow green
        "#556B2F", # dark olive green
        "#7CFC00", # lawn green
        "#228B22", # forest green
        "#00FA9A", # medium spring green
        "#2F4F4F", # dark slate gray
        "#008B8B", # dark cyan
        "#00FFFF", # aqua
        "#E0FFFF", # light cyan
        "#6495ED", # corn flower blue
        "#191970", # midnight blue
        "#0000FF", # blue
        "#8A2BE2", # blue violet
        "#4B0082", # indigo
        "#BA55D3", # medium orchid
        "#D8BFD8", # thistle
        "#FF00FF", # magenta
        "#FF1493", # deep pink
        "#FAEBD7", # antique white
        "#F5F5DC", # beige
        "#8B4513", # saddle brown
        "#D2691E", # chocolate
        "#BC8F8F", # rosy brown
        "#778899", # light slate gray
        "#B0C4DE", # light steel blue
        "#696969", # dim gray
        "#C0C0C0", # sliver
        "#DCDCDC", # gainsboro
        "#000000", # black
        "#3571c6", # Red Bull
        "#ff2800", # Ferrari
        "#6cd3bf", # Mercedes
        "#f58021", # Mclaren
        "#358c75", # Aston Martin
        "#2193d1", # Alpine
        "#37bedd", # Williams
        "#c92d4b", # Alfa Romeo
        "#b6babd", # Haas
        "#5e8faa", # Alpha Tauri
    ]

    CONSTRUCTOR_COLORS = {
        williams: "#37bedd",
        red_bull: "#3571c6",
        ferrari: "#ff2800",
        mercedes: "#6cd3bf",
        mclaren: "#f58021",
        alfa: "#c92d4b",
        haas: "#b6babd",
        alphatauri: "#5e8faa",
        aston_martin: "#358c75",
        alpine: "#2193d1",
    }

    def peak_elo_race_result
        self.race_results.order(new_elo: :desc).first
    end

    def lowest_elo
        self.race_results.pluck(:new_elo).min
    end

    def country
        countries.first
    end
    
    def season_driver_standings(season)
        driver_standings.select { |ds| ds.race.year == season.year.to_i }.sort_by { |ds| ds.race.date }
    end

    def current_constructor
        season_drivers.find_by(active: true).constructor
    end

    def constructor_for(season)
        season_drivers.find_by(season: season).constructor
    end

    CHAMPIONS = [
        {:driver_id=>643, :year=>1950},
        {:driver_id=>580, :year=>1951},
        {:driver_id=>648, :year=>1952},
        {:driver_id=>648, :year=>1953},
        {:driver_id=>580, :year=>1954},
        {:driver_id=>580, :year=>1955},
        {:driver_id=>580, :year=>1956},
        {:driver_id=>580, :year=>1957},
        {:driver_id=>579, :year=>1958},
        {:driver_id=>356, :year=>1959},
        {:driver_id=>356, :year=>1960},
        {:driver_id=>403, :year=>1961},
        {:driver_id=>289, :year=>1962},
        {:driver_id=>373, :year=>1963},
        {:driver_id=>341, :year=>1964},
        {:driver_id=>373, :year=>1965},
        {:driver_id=>356, :year=>1966},
        {:driver_id=>304, :year=>1967},
        {:driver_id=>289, :year=>1968},
        {:driver_id=>328, :year=>1969},
        {:driver_id=>358, :year=>1970},
        {:driver_id=>328, :year=>1971},
        {:driver_id=>224, :year=>1972},
        {:driver_id=>328, :year=>1973},
        {:driver_id=>224, :year=>1974},
        {:driver_id=>182, :year=>1975},
        {:driver_id=>231, :year=>1976},
        {:driver_id=>182, :year=>1977},
        {:driver_id=>207, :year=>1978},
        {:driver_id=>222, :year=>1979},
        {:driver_id=>178, :year=>1980},
        {:driver_id=>137, :year=>1981},
        {:driver_id=>177, :year=>1982},
        {:driver_id=>137, :year=>1983},
        {:driver_id=>182, :year=>1984},
        {:driver_id=>117, :year=>1985},
        {:driver_id=>117, :year=>1986},
        {:driver_id=>137, :year=>1987},
        {:driver_id=>102, :year=>1988},
        {:driver_id=>117, :year=>1989},
        {:driver_id=>102, :year=>1990},
        {:driver_id=>102, :year=>1991},
        {:driver_id=>95, :year=>1992},
        {:driver_id=>117, :year=>1993},
        {:driver_id=>30, :year=>1994},
        {:driver_id=>30, :year=>1995},
        {:driver_id=>71, :year=>1996},
        {:driver_id=>35, :year=>1997},
        {:driver_id=>57, :year=>1998},
        {:driver_id=>57, :year=>1999},
        {:driver_id=>30, :year=>2000},
        {:driver_id=>30, :year=>2001},
        {:driver_id=>30, :year=>2002},
        {:driver_id=>30, :year=>2003},
        {:driver_id=>30, :year=>2004},
        {:driver_id=>4, :year=>2005},
        {:driver_id=>4, :year=>2006},
        {:driver_id=>8, :year=>2007},
        {:driver_id=>1, :year=>2008},
        {:driver_id=>18, :year=>2009},
        {:driver_id=>20, :year=>2010},
        {:driver_id=>20, :year=>2011},
        {:driver_id=>20, :year=>2012},
        {:driver_id=>20, :year=>2013},
        {:driver_id=>1, :year=>2014},
        {:driver_id=>1, :year=>2015},
        {:driver_id=>3, :year=>2016},
        {:driver_id=>1, :year=>2017},
        {:driver_id=>1, :year=>2018},
        {:driver_id=>1, :year=>2019},
        {:driver_id=>1, :year=>2020},
        {:driver_id=>830, :year=>2021},
        {:driver_id=>830, :year=>2022}
    ]
end
