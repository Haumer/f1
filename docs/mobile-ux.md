# Mobile-first polish

## Guardrails

- Keep the navigation structure and the app's champion/team accent colours.
- Preserve useful desktop density. Phone-specific spacing and sizing live behind the 768px breakpoint.
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

## Next passes, not implemented here

1. Mobile result rows: make currently hidden grid/points/status details available
   without turning comparison tables into long stacks of cards.
2. Trading: clearer direction/quantity/cost review and a compact mobile cart.
   Align the market's hard-coded fee/dividend explanations with the calculators.
3. Data freshness: clear awaiting-results and closed-window states, including stale local/import data.
4. Driver page: separate stats and fantasy within the page, with the chart above
   detailed career history. Do not change the top-level navigation.
