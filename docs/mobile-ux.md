# Mobile-first polish

## Guardrails

- Keep the navigation structure and the app's champion/team accent colours.
- Preserve useful desktop density. Use the existing component breakpoints for phone/tablet overrides; keep full desktop tables and sidebars.
- Keep normal race visits on results/qualifying; shared debrief links open the dedicated debrief.
- Preserve the driver graph and its medals. The driver stats/fantasy split is explicitly deferred.
- Improve existing journeys before adding analytics or more game mechanics.

## Journeys covered by this pass

| Journey | Improvement | Regression check |
| --- | --- | --- |
| Catch up on a race | Compact phone hero, three summary stats in one row, one tab row for sessions/debrief/Elo | Results higher on the phone; full desktop table remains visible |
| Qualifying → driver → Back | Selected session stored in the URL, preserving other parameters and anchors | Back and refresh retain qualifying at 320, 390 and 430px |
| Search → driver → Back | Accessible search field, restored query and a clear-search action | Search survives Back/refresh and can be reset |
| Fantasy landing → account → portfolio | Roomier phone forms, readable inputs and show/hide password | Successful signup reaches the owner's funded portfolio |
| Portfolio → picks/activity/achievements | Accessible tab buttons and URL-backed selection | Refresh preserves the selected available tab |
| Navigate on a phone | Larger menu/caret targets, reachable submenu links, focus return and scroll-lock cleanup | History and fantasy menu journeys; Escape; phone-to-desktop resize |

Tabs use buttons, selected states, associated panels and arrow/Home/End keys.
Password visibility resets before Turbo caches the form. Without JavaScript,
password inputs remain masked and the unavailable show/hide control stays hidden.
There is also a keyboard skip-to-content link and visible focus for selects and disclosures.

## Verification

Browser journeys live in `test/system/mobile_journeys_test.rb`, alongside the
existing navigation, signup/picks, fantasy and debrief tests. Use Chrome device
emulation at 320, 390 and 430px plus the 1400px desktop layout. This is not a
substitute for a final physical-device Safari/Chrome check.

Preview screenshots are generated under `tmp/screenshots/mobile-polish/` and
are not committed. Fixture screenshots validate interaction; `race-real-*`
screenshots use the local development database, not production.

## Market and race-detail follow-up (2026-09-17)

- Race/sprint/qualifying rows have a separate position disclosure below 992px.
  Hidden grid, points, status and qualifying times are available on demand. Detail
  rows stay attached when sorting; desktop columns and driver links are unchanged.
- The market keeps its desktop sidebar. At 860px and below, a compact review bar
  opens an editable trade draft. Long spend and short margin are shown separately.
- Drafts live in session storage, scoped to the portfolio and race window. They
  survive driver visits and refresh, are discarded when the window changes/closes,
  and clear only after a successful trade. Storage failures do not prevent trading.
- Review fetches a private, uncached quote. POST rejects changed quoted prices,
  duplicate/unavailable orders, and rolls the whole batch back on failure. Existing
  trade services still enforce funds, deadlines and position limits; no pricing,
  dividend, fee or settlement formula was changed.
- Rules copy reads calculator constants, replacing the obsolete fixed dividend
  table and 2% fee. Current settlement uses the Elo rank at settlement, not the
  debrief model's pre-race expectation.
- Market deadlines use the actual one-minute-before-start cutoff (midnight
  fallback for unknown starts). Picks use race start. Both show local time with
  a UTC fallback and a countdown. Saving picks no longer incorrectly says locked.
- Missing-session copy distinguishes upcoming, recently started/awaiting results,
  and unavailable historical data. It does not claim a session is live or that an
  import succeeded just because its scheduled time passed.

Tests: `market_polish_test.rb`, `race_details_test.rb`, controller tests for
quotes/batch rollback, and helper tests for missing-session states. No production
accounts or trades are needed for these checks.

## Still deferred

1. Driver page: separate stats and fantasy within the page, with the chart above
   detailed career history. Do not change the top-level navigation.
2. Broader data freshness instrumentation: source sync timestamps and explicit
   per-provider coverage need data-pipeline work, not assumptions in UI copy.

## Picks editor follow-up (2026-09-17)

- The scoring goal comes from `ScoreRacePicks.scoring_limit_for`, capped to the
  available grid. The top ten is the normal goal; older rules retain full-grid
  scoring. Partial picks still save. Ranking beyond the scoring goal is an
  explicit optional step; random fill respects the current goal and preserves
  manual/random sources. No scoring or reward formula changed.
- At 768px and below, a fixed Review / Save bar shows progress and whether changes
  are unsaved, saved/editable, saving, or locked. Review jumps to the order and
  returns keyboard focus there. The bar stays above the footer, below navigation.
  Desktop retains its multi-column driver grid, team/Elo columns, drag ordering,
  and in-page sticky save action. Phone card names get their own row.
- Native driver buttons, labelled up/down/remove controls, and a bounded Undo
  history supplement dragging. Undo covers selection, moves, removal, random
  fill and clearing. Existing scorecards are not restyled.
- Drafts use session storage scoped to account (or guest) and race. Refresh and
  navigation restore them; a saved-record version prevents an old local draft
  replacing newer saved picks. Storage failure leaves explicit saving available.
  Turbo does not cache the editor, so Back reloads the current server baseline.
- Successful save clears only the matching draft. Validation/network failure
  keeps it. Guest stashing still continues through signup, and returning to the
  editor restores the stashed picks without calling them account-saved.
- The browser disables editing at the known deadline. The server independently
  rejects expired windows, including first-time picks, and forms carrying a
  different race ID. The existing unknown-start-time rule is unchanged.
- Portfolio chips and comparison pages distinguish saved from locked. Only the
  owner gets an Edit link on the comparison page while picks remain editable.

Browser coverage: `picks_polish_test.rb` checks a 22-driver fixture grid at 320,
390, 430, 440, 768 and 1400px, draft restoration, guest signup round trips, storage
failure, reordering/undo, optional positions and deadline expiry. Preview images
under `tmp/screenshots/picks-polish/` contain fixture data, not real race picks.
The combined personal post-race recap remains a later improvement.

## Market readability correction (2026-09-17)

- Phone rows (up to 600px) use driver, non-wrapping price and a 44px-high Trade
  disclosure. Holdings sit under the name instead of occupying another column.
  Only one driver's Long/Short options are expanded at a time; quantity editing
  remains in the draft. Desktop retains its full table, steppers and sidebar.
- The mobile review bar is absent until there is a draft, disappears after
  clearing/removing the last trade, and stays above the footer when present.
- The phone market status is compact; the cutoff explanation lives in How to
  trade. The exact local deadline, credits and position count remain visible.
- An unaffordable Long is disabled even when Short margin is affordable. Trade
  services, pricing and confirmation checks are unchanged.
- Browser coverage includes two-decimal prices, 27-share holdings and 146.33
  available credits at 320–1400px, individual price line count, row height,
  disclosures, keyboard focus, empty/restored drafts and footer hit testing.
