# F1 Elo

An Elo rating system for Formula 1 drivers and constructors, spanning every race from the 1950 British Grand Prix to the present day.

**Live:** [f1elo.com](https://f1elo.com)

## What It Does

F1 Elo applies the [Elo rating system](https://en.wikipedia.org/wiki/Elo_rating_system) — originally designed for chess — to every Formula 1 race result. After each race, every pair of drivers is compared head-to-head, and ratings shift based on actual vs. expected performance. The result is a single, continuous metric that tracks driver and constructor performance across eras.

### Features

- **Driver Elo Rankings** — Peak Elo, active Elo, historical progression charts
- **Constructor Elo** — Team ratings with family lineages (e.g. Toleman → Benetton → Renault → Lotus → Alpine)
- **Race Explorer** — Every race since 1950 with Elo changes, qualifying times, and podium data
- **Qualifying Results** — Q1/Q2/Q3 lap times with tabbed Race/Qualifying view (data from 1996+)
- **Season Standings** — Championship standings with Elo overlays
- **Driver Comparison** — Side-by-side Elo charts for any two drivers
- **Badges** — Achievement system for circuit kings, consistency, and career milestones
- **Dynamic Theming** — Page accent colors match the relevant constructor (Ferrari pages are red, Mercedes pages are teal, etc.)
- **Fantasy Mode** — Stock market-style fantasy game where driver prices are based on Elo
- **Race Predictions** — AI-generated pre-race predictions with methodology breakdown
- **Calendar** — Current season race calendar with session countdown timers

## Tech Stack

- **Backend:** Ruby on Rails 7, Ruby 3.3
- **Database:** PostgreSQL
- **Frontend:** Bootstrap 5, SCSS, Hotwire (Turbo + Stimulus)
- **Charts:** ECharts via `rails_charts` gem
- **Fonts:** IBM Plex Sans and IBM Plex Mono with system fallbacks
- **Search:** pg_search for driver autocomplete
- **Background Jobs:** Solid Queue
- **Auth:** Devise
- **Hosting:** Heroku (Basic dyno, Essential-0 Postgres)
- **Monitoring:** Sentry (error tracking), Ahoy (analytics)

## Data Sources

- **Race results & qualifying (1950–present):** [Jolpica (Ergast) F1 API](https://github.com/jolpica/jolpica-f1)
- **Driver headshots:** [OpenF1 API](https://openf1.org/)
- **Fallback images:** Wikipedia

## Setup

```bash
git clone https://github.com/Haumer/f1.git
cd f1
bundle install
bin/rails db:create db:migrate db:seed
bin/dev
```

Requires PostgreSQL running locally. Configure `config/database.yml` as needed.

`APP_HOST` defaults to `f1elo.com` for canonical URLs and the sitemap. Set it to the deployed host for
another installation. Google Analytics is disabled unless a valid `GOOGLE_ANALYTICS_ID` (for example,
`G-XXXXXXXXXX`) is configured, and its browser script loads only after visitor consent.

### Import Data

```bash
# Sync a single season
rake f1:sync YEAR=2026

# Sync a range of seasons
rake f1:sync_range YEARS=1950-2026

# Run Elo simulation
rake f1:elo_v2_simulate

# Recalculate constructor Elo after changing its scoring method
rake f1:constructor_elo_simulate

# Fetch qualifying data (1996+)
rake f1:qualifying START=1996 END=2026

# Compute driver badges
rake f1:badges

# Full sync (all seasons, Elo, careers, badges)
rake f1:full_sync
```

## Elo System

Each driver starts at a baseline rating of 2000. After every race, all finishers are compared pairwise:

- Beating a higher-rated driver earns more points than beating a lower-rated one
- Losing to a lower-rated driver costs more than losing to a higher-rated one
- K-factor scales with season length and grid size
- No seasonal regression — ratings carry over purely based on performance

The system produces meaningful separation between tiers — from developing drivers (~2000) through elite all-time greats (2600+).

Constructor ratings use the same pairwise calculation. A constructor's score for a race is the average
classified finishing position of all its entries, which keeps teams comparable when historical entry counts differ.
After changing constructor scoring code, recalculate the full history before processing another race. Production
supports a no-write preview and requires an explicit confirmation before persisting:

```bash
RAILS_ENV=production DRY_RUN=1 bin/rails f1:constructor_elo_simulate
RAILS_ENV=production CONFIRM_CONSTRUCTOR_ELO=1 bin/rails f1:constructor_elo_simulate
```

## Fantasy Mode

A stock market game built on top of the Elo system:

- **Stock Market** — Trade driver shares priced in credits (Elo ÷ 10), adjusted by market demand. Go long (profit when Elo rises) or short (profit when Elo drops). Longs earn dividends from top-10 finishes. Shorts require 50% collateral, incur a 0.25% per-race borrow fee, and are auto-liquidated at 2× loss. Up to 12 positions at a time.

## License

Original project code is available under the [MIT License](LICENSE). Third-party dependencies, data,
fonts, images, logos, names, and trademarks are not relicensed; see [Third-Party Notices](THIRD_PARTY_NOTICES.md).

## Public Launch

See the [zero-budget launch checklist](docs/public-launch.md) for search indexing, GitHub discovery,
community outreach, and measurement.
