# Implemented Features

## Driver Achievement Badges
**Status:** Complete

A badge/achievement system for drivers with 23 badge types, persisted to DB for performance.

### Model & Service
- `DriverBadge` model (`driver_badges` table) with `key`, `label`, `description`, `icon`, `color`, `value`, `tier` columns
- `DriverBadges` service computes all badges from filtered race results, persists to DB
- `DriverBadges.compute_all_drivers!` batch recomputes; `DriverBadges.assign_tiers!` ranks top 3 per category (gold/silver/bronze)
- Rake task: `f1:badges`
- **Min year filter** (default: 1996) — only counts races from the modern standardized era. Configurable via admin settings.

### Badge Types
| Category | Badges |
|----------|--------|
| Streaks | On Fire (3+ consecutive wins), Podium Machine (5+ consecutive podiums) |
| Circuit | King of [Circuit] (top 3 winners per circuit, 3+ wins each) |
| Race Craft | Recovery Artist, Lights to Flag (3+ pole-to-win), Comeback King (+15 places) |
| Elo | Elo Rocket (+80), Elo Crater (-80) |
| Milestones | One Hit Wonder, Century/Double/Triple Century (100/200/300 starts), 50/100/150/200 Finishes |
| Loyalty | Loyal Servant (80+ races with one team), Dynamic Duo (60+ races with same teammate) |
| Positive | Iron Man (90%+ finish rate), Points Machine (70%+ in points), Clean Racer |
| Undesirable | The Maldonado (25+ crashes), Cursed Machinery (30+ mechanical DNFs), Off the Pace, Blue Flag Special |
| Character | Team Hopper/Journeyman (4+/7+ teams), Always the Bridesmaid (20+ P2s), Wooden Spoon (20+ P4s), The Hülkenberg (50+ races, 0 podiums) |

### Views
- **Driver show page** (`app/views/drivers/show.html.erb`): Icon-only badges sorted by tier, with CSS tooltips. Circuit king badges show short circuit name. Gold/silver/bronze get glow ring.
- **Badges index page** (`/stats/badges`): All badges grouped by type with rankings, tier medals, driver links. Linked from Stats navbar dropdown.
- **Circuit kings partial** (`app/views/shared/_circuit_kings.html.erb`): Shows top 3 circuit winners as tiered chips. Used on:
  - Race weekend / Race day / Pre-race / Post-race homepage heroes
  - Race show page
  - Circuit show page

### Admin
- Badge minimum year setting at `/admin/settings` — defaults to 1996

### Files
- `app/services/driver_badges.rb` — badge computation service
- `app/models/driver_badge.rb` — model
- `db/migrate/20260304190805_create_driver_badges.rb` — table
- `db/migrate/20260304192119_add_tier_to_driver_badges.rb` — tier column
- `app/views/stats/badges.html.erb` — badges index
- `app/views/shared/_circuit_kings.html.erb` — circuit kings partial
- `lib/tasks/f1.rake` — `f1:badges` task

---

## Circuit Track Images
**Status:** Complete

SVG track layout images for all circuits, sourced from `julesr0y/f1-circuits-svg` GitHub repo.

### Implementation
- 78 SVGs stored in `app/assets/images/circuits/` mapped by `circuit_ref`
- `Circuit#track_image_path` and `Circuit#track_image?` model methods
- Displayed on circuit index (thumbnails), circuit show (hero), and race calendar

---

# Planned Features

## 1. Stats by Country
**Route:** `GET /stats/countries`
**Controller:** `StatsController#countries`

Show aggregated F1 statistics grouped by driver nationality.

### Data:
- Group drivers by `nationality` (via `countries` table)
- Aggregate: total drivers, total race wins (`wins`), total podiums (`podiums`), championships (from `DriverStanding` where `season_end: true, position: 1`), average peak Elo
- Sort by total championships (or toggle: wins, podiums, peak Elo)

### Page elements:
- Table: Flag, Country, Drivers, Championships, Wins, Podiums, Avg Peak Elo
- Bar chart: top 10 countries by championships (`Graphs::CountryStats`)
- Top 3 countries highlighted with podium styling

---

## 2. Constructor Comparison
**Route:** `GET /constructors/compare`
**Controller:** `ConstructorsController#compare`

Compare two or more constructors side-by-side on stats and Elo over time.

### Data:
- Reuse search/select pattern from driver compare page
- Stats: total races, wins, podiums, constructor championships, current Elo, peak Elo, active drivers
- Overlaid Elo chart using `Graphs::ConstructorElo` (already exists)

### Page elements:
- Search input with autocomplete (Stimulus controller, JSON search endpoint)
- Selected constructors as removable chips
- Elo comparison chart (overlaid lines)
- Stats comparison table

---

## 3. Circuit Historical Winners
**Route:** Already exists at `GET /circuits/:id` — enhance existing page
**Controller:** `CircuitsController#show` — add more data

### Data:
- Group race results at circuit by driver, count wins
- Sort by wins descending → "Most Successful Drivers at [Circuit]"
- Show: driver, wins, years, best finish Elo

### Page elements:
- "Most Successful Drivers" table below existing race list
- Small bar chart of top 5 drivers by wins at this circuit (`Graphs::CircuitWinners`)

---

## 4. Stats by Constructor (enhanced)
**Route:** Already exists at `GET /constructors/:id` — enhance existing page
**Controller:** `ConstructorsController#show`

### Additional data:
- Win rate (wins / total races)
- Podium rate
- Best season (most wins in a year)
- Head-to-head vs rival constructors (e.g. Ferrari vs McLaren all-time)

### Page elements:
- Add win rate and podium rate to stats hero
- "Best Season" stat card
- Season-by-season results summary table (year, wins, podiums, championship position)
