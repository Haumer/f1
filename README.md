# F1 Elo

An Elo rating system for Formula 1 drivers and constructors, spanning every race from the 1950 British Grand Prix to the present day.

## What It Does

F1 Elo applies the [Elo rating system](https://en.wikipedia.org/wiki/Elo_rating_system) — originally designed for chess — to every Formula 1 race result. After each race, every pair of drivers is compared head-to-head, and ratings shift based on actual vs. expected performance. The result is a single, continuous metric that tracks driver and constructor performance across eras.

### Features

- **Driver Elo Rankings** — Peak Elo, active Elo, historical progression charts
- **Constructor Elo** — Team ratings with family lineages (e.g. Toleman → Benetton → Renault → Lotus → Alpine)
- **Race Explorer** — Every race since 1950 with Elo changes, podiums, and grid data
- **Season Standings** — Championship standings with Elo overlays
- **Driver Comparison** — Side-by-side Elo charts for any two drivers
- **Badges** — Achievement system for circuit kings, consistency, and career milestones
- **Dynamic Theming** — Page accent colors match the relevant constructor (Ferrari pages are red, Mercedes pages are teal, etc.)
- **Fantasy Mode** — Roster-based and stock market-style fantasy game using Elo as currency
- **Calendar** — Current season race calendar with session countdown timers

## Tech Stack

- **Backend:** Ruby on Rails 7, Ruby 3.3
- **Database:** PostgreSQL
- **Frontend:** Bootstrap 5, SCSS, Hotwire (Turbo + Stimulus)
- **Charts:** ECharts via `rails_charts` gem
- **Fonts:** Formula1 display font family
- **Search:** pg_search for driver autocomplete
- **Background Jobs:** Solid Queue
- **Auth:** Devise

## Data Sources

- **Historical data (1950–2024):** [Ergast/Jolpica F1 API](http://ergast.com/mrd/)
- **Live season sync:** Jolpica API (automated after each race weekend)
- **Driver headshots:** [OpenF1 API](https://openf1.org/)

## Setup

```bash
git clone https://github.com/your-username/f1-elo.git
cd f1-elo
bundle install
bin/rails db:create db:migrate db:seed
bin/dev
```

Requires PostgreSQL running locally. Configure `config/database.yml` as needed.

## Elo System

Each driver starts at a baseline rating. After every race, all finishers are compared pairwise:

- Beating a higher-rated driver earns more points than beating a lower-rated one
- Losing to a lower-rated driver costs more than losing to a higher-rated one
- DNFs and grid position are factored into the calculation

The system uses a K-factor that produces meaningful separation between tiers — from developing drivers (~2000) through elite all-time greats (2600+).

## License

This project is open source and available under the [MIT License](LICENSE).
