# App Audit — 2026-03-09

## P0 — Critical

- [x] **Admin operations whitelist** — Added `ALLOWED_OPERATIONS` array, replaced dynamic dispatch with explicit allowlist.
- [x] **Wallet nil check in BaseTrade** — Added nil guard with descriptive error message.
- [x] **DNF counting nil status bug** — Fixed: require `status_type.present?` before matching.

## P1 — Important

- [x] **snapshot_portfolios O(n²)** — Replaced `portfolios.find` with `portfolios_by_id` hash lookup.
- [x] **circuits_controller missing :countries include** — Added `driver: :countries` to show action includes.
- [x] **Enable CSP in report-only mode** — Configured with all required external domains.
- [x] **Add backtrace to rescue blocks** — Added `first(5)` backtrace lines to all 3 rescue blocks.
- [x] **champions graph per-driver query** — Batch-loaded podium results upfront instead of per-driver query in `notable_events`.
- [x] **driver_badges per-circuit query** — Already uses single query with `.includes(:driver)`. No fix needed.

## P2 — Improvements

- [x] **Missing model validations** — Added `KINDS` inclusion validation to `FantasyStockTransaction`.
- [x] **Move achievement checks to background job** — Created `CheckAchievementsJob`, both roster and stock controllers now use `perform_later`.
- [x] **Missing DB indexes** — Added composite index on `fantasy_stock_transactions(portfolio_id, race_id, kind)`.
- [x] **Wallet nil in settle_race** — Added `return unless wallet` guards to pay_dividends, charge_borrow_fees, check_margin_calls.
- [x] **settle_race snapshot_prices N+1** — Batch-loaded drivers and season_drivers instead of per-driver queries.
- [x] **Prediction nil dereference** — Already safe: uses `find_by!` which raises 404.
- [ ] **Stock portfolio creation without roster check** — Can create stock portfolio without fantasy roster. (By design — stock market is independent)

## P3 — Minor

- [x] **iframe style attribute** — Removed `style` from sanitize allow-list on YouTube embeds.
- [ ] **Admin flash message sanitization** — Already safe: ERB auto-escapes flash content.
- [ ] **Driver.all.index_by in experiments** — Loads all drivers into memory. (~1000 records, acceptable)
- [ ] **No pagination on leaderboards** — Could be slow with many users. (Currently <50 users)
