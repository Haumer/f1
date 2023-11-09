class Driver < ApplicationRecord
    has_many :race_results
    has_many :driver_ratings
    has_many :constructors, through: :race_results

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

    def peak_elo_race_result
        self.race_results.order(new_elo: :desc).first
    end

    def lowest_elo
        self.race_results.pluck(:new_elo).min
    end
end
