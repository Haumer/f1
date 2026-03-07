class Driver < ApplicationRecord
    has_many :race_results
    has_many :qualifying_results
    has_many :races, through: :race_results
    has_many :driver_standings
    has_many :driver_countries
    has_many :countries, through: :driver_countries
    has_many :season_drivers
    has_many :seasons, through: :season_drivers
    has_many :constructors, through: :season_drivers
    has_many :badges, class_name: "DriverBadge", dependent: :delete_all

    validates :surname, :driver_ref, presence: true

    include PgSearch::Model 
    pg_search_scope :name_and_constructor_search,
        against: [
            [ :surname, 'A' ],
            [ :forename, 'C' ]
        ],
        associated_against: {
            constructors: [
                [ :name, 'B' ]
            ]
        }, 
        using: {
            tsearch: { prefix: true },
        }

    scope :active, -> { where(active: true) }
    scope :elite, -> { where(skill: 'elite') }
    scope :by_peak_elo, -> { order(peak_elo: :desc) }
    scope :by_first_race_date_asc, -> { order(first_race_date: :asc) }
    scope :by_first_race_date_desc, -> { order(first_race_date: :desc) }
    scope :by_last_race_date_asc, -> { order(last_race_date: :asc) }
    scope :by_last_race_date_desc, -> { order(last_race_date: :desc) }
    scope :by_surname, -> { order(surname: :asc) }

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

    CONSTRUCTOR_COLORS = Constructor::COLORS

    def peak_elo_race_result
        self.race_results.order(new_elo: :desc).first
    end

    def lowest_elo
        self.race_results.minimum(:new_elo)
    end

    # V2 equivalents
    def peak_elo_race_result_v2
        self.race_results.order(new_elo_v2: :desc).first
    end

    def lowest_elo_v2
        self.race_results.minimum(:new_elo_v2)
    end

    # Version-aware accessors
    def display_elo
        Setting.use_elo_v2? ? elo_v2 : elo
    end

    def display_peak_elo
        Setting.use_elo_v2? ? peak_elo_v2 : peak_elo
    end

    def display_lowest_elo
        Setting.use_elo_v2? ? lowest_elo_v2 : lowest_elo
    end

    def display_peak_elo_race_result
        Setting.use_elo_v2? ? peak_elo_race_result_v2 : peak_elo_race_result
    end

    def country
        countries.first
    end

    def driver_standing_for(race)
        driver_standings.find_by(race: race)
    end
    
    def season_driver_standings(season)
        driver_standings.joins(:race).where(races: { season_id: season.id }).order('races.date ASC')
    end

    def current_constructor
        season_drivers.joins(:season).order("seasons.year DESC").first&.constructor
    end

    def constructor_for(season)
        season_drivers.where(season: season).order(:id).last&.constructor
    end

    def constructors_for(season)
        season_drivers.where(season: season).order(:id).map(&:constructor).uniq
    end

    def fullname
        "#{forename} #{surname}"
    end

    def display_image_url
        if Setting.use_wikipedia_images?
            wikipedia_image_url.presence || image_url
        else
            image_url.presence || wikipedia_image_url
        end
    end

    def self.champion_standings
        DriverStanding.where(season_end: true, position: 1)
                      .includes(driver: :countries, race: :season)
                      .joins(race: :season)
                      .order('seasons.year')
    end
end
