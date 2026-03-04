class Constructor < ApplicationRecord
    include ConstructorFamilies

    has_many :race_results
    has_many :races, through: :race_results
    has_many :constructor_standings
    has_many :season_drivers
    has_many :seasons, through: :season_drivers

    validates :name, :constructor_ref, presence: true

    before_save :set_logo_url, if: -> { logo_url.blank? }

    COLORS = {
        # Current grid
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
        sauber: "#52e252",
        rb: "#5e8faa",

        # Historical teams
        lotus: "#2d6534",
        "lotus-climax": "#2d6534",
        "lotus-brm": "#2d6534",
        "lotus-ford": "#2d6534",
        team_lotus: "#2d6534",
        brabham: "#1a5c2a",
        "brabham-repco": "#1a5c2a",
        "brabham-climax": "#1a5c2a",
        "brabham-ford": "#1a5c2a",
        "brabham-bt46": "#1a5c2a",
        tyrrell: "#003580",
        brm: "#496e3d",
        "cooper-climax": "#004e2e",
        "cooper-maserati": "#004e2e",
        cooper: "#004e2e",
        maserati: "#8b0000",
        renault: "#ffcc00",
        benetton: "#00965e",
        ligier: "#0054a6",
        jordan: "#f5e642",
        bar: "#004225",
        "toro_rosso": "#001f5b",
        toyota: "#cc0000",
        honda: "#ffffff",
        force_india: "#f596c8",
        racing_point: "#f596c8",
        fittipaldi: "#d4a017",
        march: "#ff6600",
        wolf: "#c8a200",
        shadow: "#2c2c2c",
        vanwall: "#1b4d3e",
        "alfa-romeo": "#c92d4b",
    }

    LOGOS = {
        'mclaren'      => 'https://media.formula1.com/content/dam/fom-website/teams/2025/mclaren-logo.png',
        'red_bull'     => 'https://media.formula1.com/content/dam/fom-website/teams/2025/red-bull-racing-logo.png',
        'mercedes'     => 'https://media.formula1.com/content/dam/fom-website/teams/2025/mercedes-logo.png',
        'williams'     => 'https://media.formula1.com/content/dam/fom-website/teams/2025/williams-logo.png',
        'aston_martin' => 'https://media.formula1.com/content/dam/fom-website/teams/2025/aston-martin-logo.png',
        'sauber'       => 'https://media.formula1.com/content/dam/fom-website/teams/2024/kick-sauber-logo.png',
        'ferrari'      => 'https://media.formula1.com/content/dam/fom-website/teams/2025/ferrari-logo.png',
        'alpine'       => 'https://media.formula1.com/content/dam/fom-website/teams/2025/alpine-logo.png',
        'rb'           => 'https://media.formula1.com/content/dam/fom-website/teams/2024/rb-logo.png',
        'haas'         => 'https://media.formula1.com/content/dam/fom-website/teams/2025/haas-logo.png',
        'alphatauri'   => 'https://media.formula1.com/content/dam/fom-website/teams/2024/rb-logo.png',
        'alfa'         => 'https://media.formula1.com/content/dam/fom-website/teams/2024/alfa-romeo-logo.png',
    }

    # Version-aware Elo accessors
    def display_elo
        Setting.use_elo_v2? ? elo_v2 : elo
    end

    def display_peak_elo
        Setting.use_elo_v2? ? peak_elo_v2 : peak_elo
    end

    private

    def set_logo_url
        self.logo_url = LOGOS[constructor_ref]
    end
end
