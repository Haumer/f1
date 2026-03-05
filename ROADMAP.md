# F1 Elo — Project Roadmap

## What's Built

### Core Platform
- Elo rating system for all F1 drivers (1950–present), both V1 and V2 implementations
- Constructor Elo ratings with family/lineage tracking
- Race results, driver standings, constructor standings across all seasons
- Badge system (circuit kings, win streaks, podium records) computed from filtered race results
- Driver comparison tool (up to 7 drivers)
- Nationality breakdown page
- Stats pages: Elo milestones, peak Elo rankings, current active Elo

### Race Weekend Homepage
- Phase-aware homepage: pre-race, race weekend, race day, post-race, season start, season complete
- Session schedule timeline (FP1 → FP2 → FP3 → Quali → Race) with progress indicators
- Countdown to next session
- Circuit kings display per race weekend
- Post-race: podium + Elo changes
- Between weekends: next race card + previous season recap with driver/constructor podiums

### Visual Design (Dark Theme)
- Full dark theme with glassmorphism, accent colors, Formula1 fonts
- Dynamic `--page-accent` CSS variable per page (champion, driver team, race winner, constructor)
- Podium displays with constructor color accents
- Elo tier badges (Elite/World Class/Strong/Average/Developing)
- Sortable tables (client-side Stimulus controller)
- Responsive at 768px breakpoint

### Elo Explainer Page (`/elo`)
- How Elo works, the formula, K-factor explanation
- Interactive race example: pick from 10 recent races, see before/after Elo for every driver
- Tier breakdown with real driver examples and counts
- Anchor links for section sharing

### Infrastructure
- Solid Queue for background jobs (Postgres-backed)
- Job classes: PostRaceSyncJob, EloSimulateJob, BackfillCareersJob, ComputeBadgesJob
- Admin dashboard with alerts, operations panel, settings (Elo version toggle, simulated date)
- Procfile for Heroku (web + worker dynos)

### Fantasy
- Portfolio system: buy/sell drivers at Elo-based prices
- Basic portfolio card on homepage

---

## Open Features

### 1. Qualifying & Practice Data
- [ ] Import qualifying results from Jolpica API (Q1/Q2/Q3 times, all seasons)
- [ ] Import FP session results from OpenF1 API (2023+ only)
- [ ] Display quali/FP results on race pages and during race weekends

### 2. Fantasy Improvements
- [ ] Auto-score portfolios after each race sync (integrate into PostRaceSyncJob pipeline)
- [ ] Portfolio value over time chart (Elo-weighted value per race weekend)
- [ ] Scoring summary: "+X points this weekend, Y driver carried"
- [ ] Per-driver performance breakdown in portfolio view
- [ ] Rework fantasy portfolio card on homepage
- [ ] Private leagues with join codes
- [ ] Pre-race engagement ("your portfolio's exposure to this circuit")
- [ ] Push/email notifications after scoring

### 3. Kill Elo V1
- [ ] Validate V2 is the sole system
- [ ] Remove `Setting.elo_version` toggle and `Setting.elo_column()` indirection
- [ ] Drop V1 columns or stop writing to them
- [ ] Clean up all dual-column logic throughout codebase

### 4. Visual Polish
- [ ] Scroll reveal animations (IntersectionObserver Stimulus controller)
- [ ] Stat count-up animations on page load
- [ ] Mobile menu: slide-in panel from right (currently just toggling links)
- [ ] Flash messages as glass-morphism toasts
- [ ] Driver show: initials placeholder when no headshot
- [ ] Race results: status column colored icons instead of text
- [ ] Circuit pages: track SVG more visible, past race opacity reduction

### 5. Content & Data
- [ ] Driver headshots (source TBD — API, manual upload, external URL)
- [ ] Circuit hero images or track illustrations
- [ ] Richer race result presentation (beyond tables — visual storytelling)

### 6. Automation
- [ ] Cron schedule: Heroku Scheduler runs `rake f1:post_race_sync`
- [ ] Error notifications (email or webhook on sync failure)

---

## Parking Lot (future ideas, not committed)
- "What if" Elo simulator
- Elo-based race predictions
- Era/decade rankings
- "On this day in F1"
- Records page (streaks, milestones)
- Shareable driver cards for social media
- Constructor championship visual timeline
- Head-to-head driver deep comparison

---

## Tech Stack
- Rails 7, Ruby 3.3.5, PostgreSQL
- Bootstrap 5, SCSS design system, Formula1 custom fonts
- Hotwire (Turbo + Stimulus), ECharts via `rails_charts` gem
- pg_search for driver autocomplete
- Solid Queue for background jobs
- Heroku (web + worker dynos)
