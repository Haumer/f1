class Constructor < ApplicationRecord
    include ConstructorFamilies

    has_many :race_results
    has_many :qualifying_results
    has_many :races, through: :race_results
    has_many :constructor_standings
    has_many :season_drivers
    has_many :seasons, through: :season_drivers
    has_many :constructor_supports, -> { where(active: true) }
    has_many :supporters, through: :constructor_supports, source: :user

    validates :name, :constructor_ref, presence: true
    validates :constructor_ref, uniqueness: true

    def to_param
      constructor_ref
    end

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
        audi: "#d5001c",
        cadillac: "#c0a44d",

        # Historical teams
        lotus: "#4a9e5c",
        "lotus-climax": "#4a9e5c",
        "lotus-brm": "#4a9e5c",
        "lotus-ford": "#4a9e5c",
        team_lotus: "#4a9e5c",
        brabham: "#3a8c4a",
        "brabham-repco": "#3a8c4a",
        "brabham-climax": "#3a8c4a",
        "brabham-ford": "#3a8c4a",
        tyrrell: "#4a7abf",
        brm: "#6a9e5d",
        "cooper-climax": "#3a8e5e",
        "cooper-maserati": "#3a8e5e",
        cooper: "#3a8e5e",
        maserati: "#c83232",
        renault: "#ffcc00",
        benetton: "#00c878",
        ligier: "#4a8ad6",
        jordan: "#f5e642",
        bar: "#48a67a",
        "toro_rosso": "#4a6fa5",
        toyota: "#e63e3e",
        honda: "#ffffff",
        force_india: "#f596c8",
        racing_point: "#f596c8",
        fittipaldi: "#d4a017",
        march: "#ff6600",
        wolf: "#c8a200",
        shadow: "#7a7a8a",
        vanwall: "#4a8e6e",
        "alfa-romeo": "#c92d4b",
        arrows: "#e8a030",
        jaguar: "#4aaa4a",
        minardi: "#e8d44a",
        brawn: "#c8e64a",
        stewart: "#e8e8e8",
        prost: "#4a8ec8",
        footwork: "#c87830",
        super_aguri: "#e84848",
        spyker: "#e87830",
        manor: "#4a7ac8",
        marussia: "#c84848",
        caterham: "#48a848",
        hrt: "#a88030",
        virgin: "#c83030",
        lotus_f1: "#e8c830",
        lotus_racing: "#4a9e5c",
        bmw_sauber: "#5aa0d8",
    }

    LOGOS = {
        'mclaren'      => 'https://media.formula1.com/image/upload/c_fit,h_128/q_auto/v1740000000/common/f1/2026/mclaren/2026mclarenlogowhite.webp',
        'red_bull'     => 'https://media.formula1.com/image/upload/c_fit,h_128/q_auto/v1740000000/common/f1/2026/redbullracing/2026redbullracinglogowhite.webp',
        'mercedes'     => 'https://media.formula1.com/image/upload/c_fit,h_128/q_auto/v1740000000/common/f1/2026/mercedes/2026mercedeslogowhite.webp',
        'williams'     => 'https://media.formula1.com/image/upload/c_fit,h_128/q_auto/v1740000000/common/f1/2026/williams/2026williamslogowhite.webp',
        'aston_martin' => 'https://media.formula1.com/image/upload/c_fit,h_128/q_auto/v1740000000/common/f1/2026/astonmartin/2026astonmartinlogowhite.webp',
        'audi'         => 'https://media.formula1.com/image/upload/c_fit,h_128/q_auto/v1740000000/common/f1/2026/audi/2026audilogowhite.webp',
        'cadillac'     => 'https://media.formula1.com/image/upload/c_fit,h_128/q_auto/v1740000000/common/f1/2026/cadillac/2026cadillaclogowhite.webp',
        'ferrari'      => 'https://media.formula1.com/image/upload/c_fit,h_128/q_auto/v1740000000/common/f1/2026/ferrari/2026ferrarilogowhite.webp',
        'alpine'       => 'https://media.formula1.com/image/upload/c_fit,h_128/q_auto/v1740000000/common/f1/2026/alpine/2026alpinelogowhite.webp',
        'rb'           => 'https://media.formula1.com/image/upload/c_fit,h_128/q_auto/v1740000000/common/f1/2026/racingbulls/2026racingbullslogowhite.webp',
        'haas'         => 'https://media.formula1.com/image/upload/c_fit,h_128/q_auto/v1740000000/common/f1/2026/haas/2026haaslogowhite.webp',
        'sauber'       => 'https://media.formula1.com/content/dam/fom-website/teams/2024/kick-sauber-logo.png',
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
