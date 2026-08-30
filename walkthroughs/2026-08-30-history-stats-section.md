# Walkthrough — History / Stats section — 2026-08-30

**Persona:** hist_margit (fresh signup this run) · User id=15 · margit.osterlund@example.test / `Chicane!1958`
**Branch:** card-holo · **Server:** localhost:3456 · **Viewports:** 1440x900, then 390x844
**Scope:** all 17 Stats Hub destinations + the constructor support write path.

## Verdict

The numbers are trustworthy; the presentation around them is not. Every arithmetic
check passed — podium sums, teammate percentages, Title Chase points-remaining, the
fan power-ranking formula, Jim Clark's career line, the peak-Elo top 8 against
production. What repeatedly fails is the layer above: columns wired to a scope that
matches zero rows, a chart that plots future races as zeros, badges that assert
something false, and eight pages that call themselves three different things.

Fix first: **BUG 13** (Title Chase chart shows the entire grid scoring zero — one line),
then **BUG 3** (two dead columns on the flagship Peak Elo page), then **BUG 8**
(three simultaneous "Kings" per circuit, some with fewer wins than another holder).

## Steps

| # | Step | URL | Verify |
|---|---|---|---|
| 1 | Fresh signup | /users/sign_up | `User.find_by(username:"hist_margit")` |
| 2 | Stats Hub — 17 cards, 3 groups | /stats | 17 `.stats-hub-card` |
| 3 | Peak Elo | /drivers/peak_elo | top 8 vs prod peak Elo |
| 4 | By Nationality | /drivers/by_nationality | 42 groups render |
| 5 | Active Driver Elo | /drivers/current_active_elo | 22 rows |
| 6 | Driver Comparison + add Jim Clark | /drivers/compare | `?driver_ids=845,1,830,373` |
| 7 | Driver Badges | /stats/badges | `DriverBadge.count` = 542 |
| 8 | Race Wins & Podiums | /stats/race_wins | milestone brackets |
| 9 | Podium Leaders | /races/podiums | W+2nd+3rd = Pod |
| 10 | World Champions | /races/winners | 35 champions |
| 11 | Champion Timeline | /stats/champion_timeline | 76 decided seasons |
| 12 | Title Chase | /stats/title_chase | Max−Pts = 291 for all 22 |
| 13 | Elo Milestones | /stats/elo_milestones | 4 tables |
| 14 | Highest Race Elos | /races/highest_elo | 100 rows / 6 drivers |
| 15 | Circuits | /circuits | `h1` count = 0 |
| 16 | Constructor Elo | /constructors/elo_rankings | 11 active teams |
| 17 | Team Lineages | /constructors/families | 33 cards |
| 18 | Best Pairings | /constructors/best_pairings | percentages recompute |
| 19 | Fan Standings | /stats/fan_standings | formula recomputes |
| 20 | **Support Alpine** (write) | /constructors/alpine | `ConstructorSupport` 5 → 6 |

## Created records
- `User` id=15 (hist_margit)
- `FantasyStockPortfolio` / `FantasyPortfolio` auto-created on signup
- `ConstructorSupport` — hist_margit → Alpine F1 Team, season 2026, `bonus_granted: true`
  (also credited the allegiance bonus to the portfolio + a `bonus` transaction)

To clean up: destroy User id=15; the support, portfolios and transaction cascade with it.

## Bugs (all open — nothing fixed live)

## BUG 1 — 404 modulepreload on every page (site-wide)
- **Where:** config/importmap.rb:19
- **Expected:** no failed network requests on page load
- **Observed:** `<link rel="modulepreload" href="https://ga.jspm.io/npm:zrender@5.4.4/lib/">` → 404, console error on EVERY page
- **Evidence:** nothing in app/ imports zrender; echarts.min.js is vendored by the `rails_charts` gem (1,020,185 bytes, serves 200) with zrender already bundled. Pin is a leftover from an abandoned jspm echarts setup.
- **Severity:** cosmetic (wasted request + a permanent console error that masks real ones)

## BUG 2 — "75 years of Formula 1" is stale (should be 77)
- **Where:** app/views/stats/index.html.erb:9 (hero meta), :81 (Champion Timeline card desc), app/views/stats/champion_timeline.html.erb:2 (SEO meta description)
- **Expected:** a count that tracks the data, or at least the correct one
- **Observed:** hardcoded "75 years"
- **Evidence:** `Season.count` = 77, years 1950–2026 inclusive = 77 seasons. Was correct in 2024; goes stale every January.
- **Severity:** wrong-copy (one instance is an SEO meta description, so it's also public-facing to search engines)

## BUG 3 — Peak Elo: "Race" and "Year" columns are empty for every row
- **Where:** app/controllers/drivers_controller.rb:97 (`Driver.elite`), rendered by app/views/drivers/peak_elo.html.erb
- **Expected:** each of the 50 rows shows the race + year where the driver hit their peak, plus that race's constructor logo
- **Observed:** 50/50 rows blank in all three cells; two labelled columns occupy ~30% of the table with nothing in them
- **Evidence:** `@peak_race_by_driver` is built from `Driver.elite`, i.e. `where(skill: 'elite')`. `Driver.group(:skill).count` => `{nil=>865}` in DEV **and PROD**. The scope can never match. The table itself is built from `where(peak_elo_v2 > 2450)` (50 drivers) — a completely different set.
- **Fix direction:** build the peak-race lookup from `@drivers` (the same set the table renders), not from the unrelated `skill` scope. The current line is also an N+1 waiting to happen — it loads every race_result for each driver and `max_by`s in Ruby.
- **Severity:** blocks-journey (the page's two most interesting columns are dead)

## BUG 4 — No Country records exist: every flag on the site is missing
- **Where:** app/helpers/application_helper.rb:64 `flag_image`, used across the stats section
- **Expected:** a nationality flag beside each driver
- **Observed:** `flag_image` returns "" for every driver — 0 `<img>` elements in the entire Peak Elo table (50 rows)
- **Evidence:** `Country.count` = 0 and `DriverCountry.count` = 0 in DEV **and PROD**. `driver.country` returns nil for Verstappen. Controllers all over the section carry `.includes(:countries)` eager-loads for an association that is universally empty.
- **Knock-on:** the "By Nationality" hub card depends entirely on this data — see BUG 5.
- **Severity:** blocks-journey (site-wide missing content, plus wasted eager-loads)

## BUG 5 — Raw database slugs on every chart x-axis (site-wide)
- **Where:** app/services/graphs/base.rb:6 `race_x_label`
- **Expected:** a human circuit/GP label
- **Observed:** `"red_bull_ring Aug 16, 1981"`, `"zandvoort Jun 06, 1960"` — `circuit.circuit_ref`, the DB slug, printed verbatim with underscores
- **Evidence:** `race_x_label` = `"#{race.circuit.circuit_ref} #{date}"`. Called from 14 sites across 7 graph services (compare, line, ranking, season_elo, champions, constructor, base) — i.e. every Elo chart in the app.
- **Extra sting:** in the SAME chart, `compare.rb:32` builds the tooltip with `race.circuit.name`. Hovering says "Red Bull Ring"; the axis under it says "red_bull_ring".
- **Fix note:** don't just swap in `circuit.name` — several are very long ("Autodromo Enzo e Dino Ferrari"). `race.name` or a titleized ref reads better on an axis.
- **Severity:** wrong-copy, high visibility

## BUG 6 — Compare chart end-labels are clipped at the right edge
- **Where:** app/services/graphs/compare.rb (`data`, no `grid` key)
- **Expected:** "M.Verstappen (2423)" fully visible
- **Observed:** "M.Verstappen (2", "L.Hamilton (230" — truncated mid-number
- **Evidence:** series set `endLabel` with `distance: 20`, but the returned option hash defines no `grid`, so echarts uses default right padding and the labels render past it. Compare with peak_elo.html.erb, which does set `grid: {..., right: 10, containLabel: true}`.
- **Severity:** cosmetic (but it lands on the single most prominent number on the page)

## BUG 7 — "Current Elo" column shown for long-retired drivers
- **Where:** app/views/drivers/compare.html.erb results table
- **Expected:** a label that makes sense for a driver who last raced in 1968
- **Observed:** Jim Clark (d. 1968) has a "Current Elo" of 2,412
- **Note:** the same underlying value is labelled just "Elo" on /drivers/current_active_elo. Inconsistent naming for one quantity; "Final Elo" or "Last Elo" would be honest for retired drivers.
- **Severity:** wrong-copy

## BUG 8 — "King of <circuit>" is awarded to up to THREE drivers per circuit
- **Where:** app/services/driver_badges.rb:144 `check_circuit_king`
- **Expected:** one King per circuit (the most wins)
- **Observed:** 17 of 29 circuits have multiple Kings, and the badge is given to drivers who are NOT the top winner:
  - `circuit_king_22`: Hamilton(4), Schumacher(5), Vettel(4) — two "Kings" with fewer wins than Schumacher
  - `circuit_king_24`: Hamilton(5), Vettel(3), Verstappen(5) — Vettel is "King" on 3 wins vs two others on 5
  - `circuit_king_14`: Hamilton(5), Vettel(3), Schumacher(5)
  - `circuit_king_6`:  Hamilton(3), Rosberg(3), Schumacher(3)
  - Visible on the page: rows 3 and 6 are both "King of Circuit Gilles Villeneuve" (Hamilton 7, Schumacher 6)
- **Evidence:** `rank = sorted.index {...}; next unless rank && rank < 3` — the badge is granted to the **top three** winners but labelled "King of". 58 circuit_king badges exist across only 29 circuits.
- **Fix direction:** either restrict to `rank.zero?` (handling ties), or rename the badge to match what it measures ("Master of X", or tier the label by rank).
- **Severity:** wrong-copy / data-integrity — the badge asserts something false about drivers

## BUG 9 — Literal placeholder "King of [Circuit]" rendered to users
- **Where:** app/controllers/stats_controller.rb (`badges`, merged group `label: "King of [Circuit]"`)
- **Expected:** a real group heading, e.g. "Circuit Kings"
- **Observed:** the heading reads `King of [Circuit]`, square brackets and all
- **Severity:** wrong-copy (looks like an unrendered template)

## BUG 10 — Circuit Kings group is labelled "58 drivers"; it is 58 badges held by 9 drivers
- **Where:** app/views/stats/badges.html.erb:26 — `<%= group[:badges].size %> driver…`
- **Expected:** "9 drivers" (or "58 badges")
- **Observed:** "58 drivers"
- **Evidence:** `DriverBadge.where("key LIKE 'circuit_king_%'")` => 58 badges, `distinct.count(:driver_id)` => **9**. The label is only wrong here because this is the one *merged* group — every other badge key is one-per-driver, so badges.size coincidentally equals the driver count.
- **Note:** the page-level "542 badges across 74 drivers" is correct.
- **Severity:** wrong-copy

## BUG 11 — Same era rendered "2010–now" on one page and "2010–present" on another
- **Where:** app/views/stats/race_wins.html.erb:25 vs app/controllers/races_controller.rb:168
- **Expected:** one label for one era
- **Observed:** /stats/race_wins shows "HYBRID 2010–now"; /races/winners shows "HYBRID 2010–present"
- **Evidence:** both read the same `Championship::ERAS` (`"Hybrid" => 2010..2099`) and both independently reimplement the open-ended check with the same magic number: `range.last > 2050 ? "now" : ...` in the view, `year_range.last > 2050 ? 'present' : ...` in the controller. Copy-paste that drifted.
- **Severity:** cosmetic / wrong-copy

## BUG 12 — Three different season counts across one section
- 75 — /stats hub hero and Champion Timeline card (BUG 2)
- 76 — /stats/champion_timeline hero ("35 champions across 76 seasons") — **correct** for *decided* championships (1950–2025; 2026 is mid-season, 11/22 races scored)
- 77 — `Season.count`, the actual number of seasons in the database
- The 76 is right for what it says. The 75 is simply stale. Worth making both derive from data so they can't drift again.

## NOTE — "N x" badge duplicates the adjacent Titles column
- **Where:** /races/winners and /stats/champion_timeline champion tables
- Rows render as `M. Schumacher 7x | 7 | 1994, …` — the "7x" chip sits directly beside a "Titles" column containing 7. Not a defect, but one of the two is redundant.

## NOTE — /stats/race_wins milestone table has a mostly-empty "Names" column
- **Where:** app/views/stats/race_wins.html.erb:49 — `<% if m[:count] <= 5 %>`
- 7 of 9 win-milestone rows render a blank Names cell (25+ wins shows 11 drivers, no names).
- Also, count and names disagree by design: "50+ wins | **5** | M. Schumacher, M. Verstappen, S. Vettel, A. Prost" lists **4** names, because `build_milestones` reports a cumulative `count` but a de-duplicated `drivers` list (Hamilton already appeared in the 100+ row). Reads like an off-by-one.

## BUG 13 — Title Chase points chart shows every driver collapsing to 0 mid-season
- **Where:** app/services/graphs/championship_race.rb:57
- **Expected:** each cumulative-points line stops at the last scored round (R11)
- **Observed:** all five lines rise to R11 then fall vertically to zero and run flat along the axis for R12–R22. The chart reads as if the whole grid was disqualified.
- **Evidence:** `data: @races.map { |r| standings.dig(driver.id, r.id) || 0 }`. `@races` is the full 22-race 2026 calendar; only **11** have `driver_standings`. Every unscored future round therefore plots a literal 0 on a *cumulative* series.
- **Fix:** emit nil/"" for missing rounds so echarts draws a gap. The codebase already does exactly this in `Graphs::Compare` (compare.rb:36 → `{ value: "" }`).
- **Irony:** the same file's `latest_race` lookup (line ~21) deliberately guards against future races — "not the calendar's final race, which may be in the future or unsynced" — the author saw the problem for standings and missed it for the series data.
- **Severity:** blocks-journey (flagship chart of the page, actively misleading)
- **Note:** the rest of Title Chase is sound — Max−Pts is exactly 291 for all 22 drivers (11 races × 25 + 2 sprints × 8), and "Max per round 33 = 25 race + 8 sprint" checks out.

## BUG 14 — /stats/elo_milestones: all four tables are degenerate
- **Where:** app/controllers/stats_controller.rb `elo_milestones`
- a) **"Biggest Single-Race Elo Gain" — 5 of 10 rows are the Indianapolis 500.** Top 3 are T.Bettenhausen, J.Thomson, B.Homeier at Indianapolis 1955.
- b) **"Biggest Single-Race Elo Drop" — 8 of 10 rows are Indianapolis.**
- c) **"Highest Elo Entering a Race" — 8 of 10 rows are Verstappen**, the other 2 Hamilton. Rows 1–3 are three consecutive 2024 races. A "top 10" listing one driver ten times is a sorted dump, not a record list.
- d) **"Fastest Rising Careers" — the "Start Elo" column reads 2000 on all 10 rows.** It is the seed rating by construction (`rn = 1` old_elo), so the column carries no information and "Elo Gain" is just `After 20 Races − 2000`.
- **Root cause (a,b):** the Indy 500 counted for the World Championship 1950–1960, but its entrants were American oval racers with no other F1 starts. One-off appearances against an unrated field produce huge rating swings that are artifacts, not performances. Nothing filters them out.
- **Fix direction:** (a,b) exclude Indianapolis 1950–1960, or require a minimum career start count; (c) dedupe to one entry per driver (their own highest); (d) drop the constant column or show the driver's pre-20-race baseline.
- **Severity:** wrong-copy / data-quality — the page is titled "records" but mostly surfaces artifacts

## BUG 15 — /circuits has no <h1> and no page hero
- **Where:** app/views/circuits/index.html.erb
- **Expected:** the section's standard `.page-hero` with label + `<h1>`, like all 16 sibling pages
- **Observed:** `document.querySelectorAll('h1').length` === **0**. First heading on the page is an `<h3>` ("2026 Calendar"), so the heading order is h3 → h3 with no h1 anywhere.
- **Impact:** accessibility (no document heading, skipped levels), SEO, and a visible style break — it is the only destination in the Stats Hub without the hero treatment.
- **Also:** the hub card promises "All tracks with race history and kings", but the page opens with a 2026 calendar map; the circuit list is below the fold.
- **Severity:** blocks-journey for a11y, cosmetic otherwise

## BUG 16 — Every page in the section has up to three different names
| Path | Hub card | `<title>` | `<h1>` |
|---|---|---|---|
| /races/highest_elo | Highest Race Elos | Highest Elo Performances | Highest Elo Race Results |
| /stats/fan_standings | Fan Standings | Community Standings | Where the crowd stands |
| /drivers/peak_elo | Peak Elo Rankings | All-Time Peak Elo Rankings | All-Time Peak Elo |
| /constructors/best_pairings | Best Pairings | Best Teammate Pairings | Best Teammate Pairings |
| /races/podiums | Podium Leaders | Most Podiums | Podium Leaders |
| /drivers/compare | Driver Comparison | Compare Drivers | Compare Drivers |
| /drivers/by_nationality | By Nationality | Drivers By Nationality | Drivers By Nationality |
| /constructors/elo_rankings | Constructor Elo | Constructor Elo Rankings | Constructor Elo |
- **Worst:** `/races/highest_elo` and `/stats/fan_standings` — three genuinely different names each. A user who clicks "Fan Standings" lands on a page headed "Where the crowd stands" with a browser tab reading "Community Standings".
- **Severity:** wrong-copy (navigation confidence — the click target and the destination don't match)

## BUG 17 — "Top" lists that are one driver repeated
- **/races/highest_elo:** 100 rows, **6 distinct drivers**. Rows 1–6 are all Verstappen, consecutive 2023–24 races.
- **/stats/elo_milestones "Highest Elo Entering a Race":** 8 of 10 rows Verstappen (see BUG 14c).
- Because Elo moves slowly, sorting raw per-race ratings returns one driver's plateau. Both lists want one row per driver (their best), which is what a reader assumes a leaderboard means.
- **Severity:** wrong-copy / low-value content

## BUG 18 — Duplicated site suffix in <title>
- **Where:** app/views/stats/fan_standings.html.erb:1 and app/views/users/profile.html.erb:1
- **Expected:** "Community Standings — F1 Elo"
- **Observed:** `<title>Community Standings — F1 Elo — F1 Elo</title>` (and "@hist_margit — F1 Elo — F1 Elo")
- **Evidence:** the layout already appends the suffix — `app/views/layouts/application.html.erb:4`: `safe_join([yield(:title), " — F1 Elo"])`. These two views hardcode it a second time inside `content_for(:title)`. They are the only two that do.
- **Knock-on:** `og:title` and `twitter:title` use the raw `yield(:title)`, so the doubled name is what gets shared to social cards too.
- **Severity:** wrong-copy (visible in browser tab + link previews)

## BUG 19 — `@user_supports_any` is never assigned
- **Where:** app/views/constructors/show.html.erb:17 — `<% if current_user && !@user_supports_any && ConstructorSupport.can_change?(...) %>`
- The variable is referenced in this guard and **defined nowhere** in the codebase (grep across app/controllers and app/views returns only this line). It is therefore always `nil`, so `!@user_supports_any` is permanently `true` and the condition it was meant to add does nothing.
- Currently harmless because `can_change?` carries the real logic, but it is a dead guard that reads as if it works.
- **Severity:** latent / code-health

## BUG 20 — RB F1 Team has no nationality
- **Where:** /constructors/elo_rankings, Nationality column
- **Observed:** blank cell for RB F1 Team; all 10 other active constructors have one.
- **Evidence:** `Constructor.where(active: true)` → RB F1 Team is the only one with `nationality = nil`.
- **Severity:** cosmetic / data gap

## VERIFIED CORRECT (checked, no defect)
- Peak Elo top 8 matches production exactly (Verstappen 2743, Hamilton 2714, Clark 2681, Vettel 2641, Reutemann 2626, Schumacher 2626, Rosberg 2617, Fangio 2617)
- Jim Clark career line: 72 races / 25 wins / 32 podiums / 2 titles — matches real history
- Podium tables: W + 2nd + 3rd = Pod on every row, and podium counts agree between /races/podiums and /stats/race_wins
- Best Pairings: every Win% and 1-2% recomputes correctly (Hamilton/Rosberg 54/78 = 69.2%, 31/78 = 39.7%)
- Title Chase: Max − Pts = 291 for all 22 drivers = 11 races x 25 + 2 sprints x 8; "Max per round 33 = 25 + 8" correct
- Fan Standings power-ranking formula (longs x3 + P1 x2 - shorts) recomputes correctly on every row
- Champion Timeline "35 champions across 76 seasons" is right (76 = decided championships 1950-2025)
- Team Lineages chains are historically accurate
- Constructor support write path: 5 -> 6 loyalists, bonus granted, percentages sum to 100%
- SweetAlert confirm's hidden "No" button is SweetAlert2's always-rendered deny element, not a stray control
