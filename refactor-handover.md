# Refactor Handover — F1 Elo

**Purpose:** Hand this to a fresh Claude Code session to execute the refactor pass. The audit is already done; this doc contains everything needed to act without re-auditing.

**Companion doc:** `refactor.md` (the user's refactor rules — read it first).

**Scope of this handover:** Refactor only. A separate session is handling community/fan features. Do **not** touch community/social work — those files may be actively changing.

---

## Context

F1 Elo (`f1elo.com`) — Rails 7 fan site: driver/constructor Elo, race explorer since 1950, fantasy stock market, race picks, H2H, driver preference matching, badges.

- Ruby 3.3, Rails 7, PostgreSQL, Bootstrap 5, SCSS, Hotwire (Turbo + Stimulus)
- Charts: `rails_charts` (ECharts), Search: `pg_search`, Jobs: Solid Queue, Auth: Devise
- Hosting: Heroku (Basic dyno, Essential-0 PG), Monitoring: Sentry + Ahoy

## Ground rules (from user memory — DO NOT VIOLATE)

- **Worktree paths.** If invoked in a worktree, use the worktree path for all edits and commits. Never edit or commit via the parent repo path — commits land on `main` if you do.
- **SCSS precompile check.** Before pushing any SCSS change, run a **prod precompile dry-run** (`RAILS_ENV=production bin/rails assets:precompile`). SassC's compressor re-parses CSS and rejects `min()`/`calc()` that the dev compile accepted. Do not skip this.
- **Snapshots must use historical Elo.** Never write `driver.elo_v2` into a snapshot — use the historical Elo at that point in time.
- **ReplayTransactions must be sequential per race, and preserve original timestamps.** Do not batch across races; do not overwrite trade timestamps.
- **Heroku:** default to `heroku run rails c`. Only fall back to `heroku run rails runner` with a stated reason.
- **AI-generated content:** never insert into the DB without user approval.
- **Source-of-truth data:** never write to it; test on a copy or with `--dry-run`.

## Process (per `refactor.md`)

1. Read `refactor.md` in full.
2. For each item below: read the referenced files, verify the finding is still accurate (some may already be fixed), then execute.
3. Run tests after each item. `bin/rails test` unless the user has a preferred subset.
4. Present the change to the user for review before committing (per user preference for AI-generated content review — err on the side of showing diffs).
5. Commit per item, not in one blob. Follow existing commit style: `git log --oneline -10`. Concise, imperative, subject line reads like a headline. No Claude co-author signature unless the user requests it.

---

## Findings — ranked by leverage

### KILL ZONE (do these first — biggest wins, unblock later items)

#### R1. Delete the dead roster fantasy system

**What:** The old roster-based fantasy game was replaced by the stock market. Models, views, controllers still exist but appear orphaned.

**Files to verify + likely delete:**
- Models: `app/models/fantasy_roster_entry.rb`, `app/models/fantasy_transaction.rb`, `app/models/fantasy_achievement.rb`, `app/models/fantasy_snapshot.rb`
- Views: `app/views/fantasy_portfolios/roster.html.erb`, `app/views/fantasy_portfolios/market.html.erb`
- Possibly whole controller actions in `fantasy_portfolios_controller.rb` (roster/market actions)
- Any related jobs, services (`app/services/fantasy/*` — some may be roster-era)

**Verification steps before deleting:**
1. `grep -r "FantasyRosterEntry\|FantasyTransaction\|FantasyAchievement" app/ config/ lib/ test/` — must be zero hits outside the model file itself.
2. `grep -rn "fantasy_portfolios_path\|roster\|/fantasy/market" app/views app/controllers config/routes.rb` — check whether the roster/market routes are still hit.
3. Check `config/routes.rb` for routes that would be dead-linked.
4. Check `db/schema.rb` — tables still exist. **Do not drop tables in this pass** — flag them for a follow-up migration and confirm with user first (destructive, needs backup consideration).
5. Confirm with user before deleting. This is destructive and touches production code paths.

**Expected impact:** ~300 LOC removed. Clarifies "which fantasy game is live". Unblocks R3 and R4.

**Caveat:** `FantasyPortfolio` (roster) vs `FantasyStockPortfolio` (stock) are separate models. The stock one stays. Don't confuse them.

---

#### R2. Extract `Fantasy::Stock::SettlementCalculator`

**What:** ~80 LOC of settlement logic is duplicated between two services (dividend calc, borrow fees, margin calls, constructor multiplier).

**Files:**
- `app/services/fantasy/replay_transactions.rb` (444 LOC) — lines ~278-315, ~345-361
- `app/services/fantasy/stock/settle_race.rb` (251 LOC) — lines ~60-151, ~230-248

**Fix:** Create `app/services/fantasy/stock/settlement_calculator.rb` as a pure calculator. Inputs: race, driver, price, elo_rank. Outputs: `{ dividend_per_share:, borrow_fee_per_share:, margin_call_price:, constructor_multiplier: }`. Both callers use it. Ensure replay path still preserves original timestamps (per ground rule).

**Test:** existing service tests should pass unchanged. Add a unit test for the calculator itself.

**Expected impact:** ~50 LOC saved, single source of truth for the money math.

---

#### R3. Consolidate three cart Stimulus controllers

**What:** `fantasy_cart_controller.js`, `stock_cart_controller.js`, `unified_cart_controller.js` all exist. The unified one was written to replace the other two but the old ones are still registered/shipped.

**Files:**
- `app/javascript/controllers/fantasy_cart_controller.js` (~164 LOC)
- `app/javascript/controllers/stock_cart_controller.js` (~169 LOC)
- `app/javascript/controllers/unified_cart_controller.js` (~269 LOC)
- `app/javascript/controllers/index.js` (registration)

**Fix:**
1. Grep views for `data-controller="fantasy-cart"` and `data-controller="stock-cart"`.
2. If unified covers both, migrate remaining references to `unified-cart`, then delete the two old files.
3. If unified only covers stock (given R1 kills roster), delete `fantasy_cart_controller.js` outright and rename `unified_cart_controller.js` → `stock_cart_controller.js` (replacing the old one). Or the reverse — pick whichever is closer to reality.

**Verify:** cart interactions still work — buy/sell flow on `/fantasy/stocks` (or wherever the market lives now).

**Expected impact:** ~400 LOC removed.

---

#### R4. Extract shared portfolio partials

**What:** `fantasy_portfolios/{overview,public_profile,show}.html.erb` are ~1400 LOC combined with ~80% layout overlap (hero, tabs, holdings table, KPI strip).

**Files:**
- `app/views/fantasy_portfolios/overview.html.erb` (599)
- `app/views/fantasy_portfolios/show.html.erb` (493)
- `app/views/fantasy_portfolios/public_profile.html.erb` (339)

**Partials to extract:**
- `_dashboard_header.html.erb` — hero title/season/is_owner/actions
- `_status_strip.html.erb` — the fantasy-status-row / stat chip strip
- `_holdings_table.html.erb` — the shared holdings table
- `_portfolio_kpis.html.erb` — cash / invested / P/L headline blocks

**Also add helper:** `app/helpers/fantasy_portfolios_helper.rb` with `portfolio_summary(portfolio, stock_portfolio)` returning `{cash:, invested:, pl:, pl_pct:, allocation:}`. Kills the 20-30 line `<% %>` math blocks that repeat in all 3 views.

**Expected impact:** ~150 LOC saved, view drift stops.

---

### HIGH-LEVERAGE EXTRACTIONS

#### R5. Move `HomepageData` concern → `Homepage::Builder` service

**File:** `app/controllers/concerns/homepage_data.rb` (226 LOC).

**Smell:** It's a query object in disguise (session schedules, phase detection, connector progress, Elo rankings). Logic-heavy concern coupled to controller.

**Fix:** Move to `app/services/homepage/builder.rb`. Public API: `Homepage::Builder.new(user: current_user, season: current_season).call` → returns a struct/hash. `PagesController#home` calls it via `before_action`. Concern goes away.

**Test:** homepage phases render identically for logged-out, race-weekend, post-race, season-complete states.

**Expected impact:** homepage phase logic becomes testable in isolation without controller fixtures.

---

#### R6. Extract `Constructors::ShowPresenter` and `Constructors::PairingCalculator`

**File:** `app/controllers/constructors_controller.rb` (328 LOC).

**Smells:**
- `#show` action is 86 lines (constructors_controller.rb:94-179) — 12 separate data computations inline.
- `#best_pairings` action is 75 lines (constructors_controller.rb:190-265) — nested loops, dedup, cross-season matching all inline.

**Fix:** Two service objects. Controller becomes a thin dispatcher (`@presenter = Constructors::ShowPresenter.new(constructor).call`).

**Also here:** N+1 fix. Line 75 and 157-160 iterate `race.year` without preloading. Add `.includes(race: [:circuit, :season])`.

---

#### R7. Extract `Seasons::ShowPresenter`

**File:** `app/controllers/seasons_controller.rb` (225 LOC).

**Smell:** `#show` (48 lines) + 175 lines of private `build_*` methods (stats, constructor standings, grid, recap, pre-season).

**Fix:** Single presenter service that returns all needed data. Also fixes a missing `.includes()` on constructor standings.

---

#### R8. `Race#settlement_cutoff_time` and `#settlement_time`

**Pattern:** `race.starts_at || race.date` (or `.to_time`) appears **8+ times** across fantasy services with subtle variations. Sometimes used for cutoff, sometimes for settlement time (+4h).

**Fix:** Add to `app/models/race.rb`:
```ruby
def settlement_cutoff_time
  starts_at || date.beginning_of_day
end

def settlement_time
  (starts_at || date.to_time) + 4.hours
end
```
Grep + replace all 8+ occurrences.

**Callers to update:**
- `app/services/fantasy/replay_transactions.rb` (~lines 34, 254, 374)
- `app/services/fantasy/stock/settle_race.rb` (~lines 64, 99, 124)

**Test:** replay a race, confirm identical output — same trade timestamps preserved (ground rule).

---

#### R9. `FantasyStockHolding.before_race(race)` scope

**Pattern:** `.where("created_at < ?", @race.starts_at || @race.date)` in ~6 places.

**Fix:** Add scope on `FantasyStockHolding`:
```ruby
scope :before_race, ->(race) { where("created_at < ?", race.settlement_cutoff_time) }
```
(Depends on R8.)

Replace 6 callers. Similar scope on `FantasyStockTransaction` if the same pattern lives there.

---

#### R10. `DisplayElo` concern for `Driver` + `Constructor`

**Files:**
- `app/models/driver.rb` lines ~103-117
- `app/models/constructor.rb` lines ~107-113

**Smell:** Identical `display_elo` / `display_peak_elo` methods.

**Fix:** `app/models/concerns/display_elo.rb`. Include in both models. **Note:** these are simple delegations to the DB column — verify there isn't per-model formatting divergence before extracting.

**Also consider:** if the whole `display_*` cluster on `Driver` (5 methods, ~15 LOC) is pure presentation, move to `DriverPresenter` or a helper. But scope this to just the shared ones — larger presenter migration is a follow-up.

---

### CORRECTNESS / SMALLER WINS

#### R11. N+1 fixes

- `ConstructorsController#index` and `#grid` — add `.includes(race: [:circuit, :season])` (constructors_controller.rb:72-91).
- `SeasonsController` constructor standings query — flagged by audit but confirm before adding.
- `graphs/ranking.rb` (lines 56-60, 143-147) — constructor loaded per driver twice; cache once in initializer.

---

#### R12. Missing model validations

**Files:**
- `app/models/race_result.rb` — add `validates :position, :points, presence: true`.
- `app/models/fantasy_stock_holding.rb` — add `validates :opened_race_id, :fantasy_stock_portfolio_id, :driver_id, presence: true`.
- `app/models/fantasy_stock_snapshot.rb`, `app/models/stock_price_snapshot.rb` — currently empty, add presence validations for their NOT NULL FKs.

**Check schema first** (`db/schema.rb`) to confirm NOT NULL — don't add validations the DB doesn't back.

---

#### R13. `Status` model → config

**File:** `app/models/status.rb` (71 LOC).

**Smell:** It's classification constants (`TECHNICAL_REASONS`, `DRIVER_HEALTH_REASONS`, etc.) with no real DB behavior beyond `find_by_id`.

**Fix options (pick one, ask user):**
- (a) Move constants to `config/finish_statuses.yml`, load into a `StatusRegistry` PORO. Keep the ActiveRecord model thin (associations only).
- (b) Convert to an enum on `RaceResult`.

Recommend (a) — less migration risk.

---

#### R14. `User#after_create :alert_first_portfolio` → job

**File:** `app/models/user.rb` lines ~74-81.

**Smell:** Model has a callback that creates admin alerts. If the alert fails, user creation rolls back. Side effect in model.

**Fix:** Extract to `UserCreatedJob` (perform_later from the callback, or trigger from `Users::RegistrationsController`).

---

#### R15. Shared view partials

**Extract:**
- `app/views/shared/_stat_card.html.erb` — used in `races/show`, `constructors/show`, `seasons/show`, `drivers/show`. Locals: `label, value, detail, class_names`.
- `app/views/shared/_empty_state.html.erb` — pattern in `fantasy_portfolios/overview:342-354` and elsewhere. Locals: `icon, title, body, cta_label, cta_path`.
- `app/views/pages/_elo_tier_card.html.erb` — five identical `elo-tier-card` blocks in `pages/elo.html.erb:61-142`.
- `app/views/fantasy_portfolios/_visibility_toggle.html.erb` — duplicated in `show` + `public_profile`.

**Expected impact:** ~230 LOC across views.

---

#### R16. Memoize `Setting.elo_column(...)`

**Pattern:** Called 20+ times per request uncached.

**Fix:** Memoize on `ApplicationController`:
```ruby
def elo_columns
  @elo_columns ||= {
    elo: Setting.elo_column(:elo),
    peak_elo: Setting.elo_column(:peak_elo),
    new_elo: Setting.elo_column(:new_elo)
  }
end
helper_method :elo_columns
```
Replace call sites incrementally.

---

## Items I recommend NOT doing (or asking user first)

- **Dropping the roster DB tables** (from R1) — destructive, needs migration + backup coord.
- **Unifying `FantasyPortfolio` + `FantasyStockPortfolio` into one polymorphic model** — the audit flagged this but it's a big design decision. If R1 kills roster, this becomes moot.
- **Rewriting `wikipedia_race_result_fetcher.rb` (393 LOC)** — it's long but working. Ask the user before touching this; it's on the race sync critical path.
- **`graphs/ranking.rb` (270 LOC) restructure** — flagged but the top-priority items above are higher leverage. Do after R1-R10 if there's time.

---

## Execution order recommendation

1. **R1** first (verify + delete dead roster) — unblocks R3, R4, and many partial extractions.
2. **R2, R8, R9** together (all touch fantasy settlement services) — one PR.
3. **R10, R11, R12, R16** as quick wins — small independent commits.
4. **R3** (cart controllers).
5. **R4** (portfolio views).
6. **R5, R6, R7** (controller extractions) — bigger, do last, one at a time.
7. **R13, R14, R15** as time permits.

Estimated ~1000 LOC removed with no behavior change.

---

## When you're done

- Update `audit.md` — that's where the user tracks resolved items. Add a dated section for this pass.
- Do NOT create a summary markdown file unless asked. Report via commit messages + PR description.
