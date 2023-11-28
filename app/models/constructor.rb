class Constructor < ApplicationRecord
    has_many :race_results
    has_many :races, through: :race_results

     COLORS = {
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
end
