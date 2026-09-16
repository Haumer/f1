# Deferred product ideas

Bookmarked from the September 15–16, 2026 conversation.

## Current decision: polish first

The user's preference is to polish the existing app before expanding its feature
set. The ideas below are parked, not an approved implementation plan. Do not start
imports, modelling, prediction games or prize features without revisiting them.

Polish should preserve the preferences already established:

- Keep the driver-graph medals.
- Follow the app's existing theming, including the reigning-champion accent where
  applicable; avoid giving new sections an unrelated palette.
- Put useful data before lengthy explanations; keep supporting prose in accessible
  disclosures or tooltips.
- Normal race visits show results/qualifying first; shared debrief links open the
  debrief directly for that specific race.
- Make fantasy attractive and understandable without repetitive sharing prompts
  or signed-out onboarding banners in signed-in views.
- Check mobile layouts, navigation, loading speed, empty states and account flows
  before adding more analytical depth. These are review areas, not a new bug audit.

## Tyres: “The Rubber Report”

- Race-wide compound usage: stint count, drivers using each compound and summed
  driver-laps, with the unit explicit. Stints are not unique physical tyre sets.
- Longest stint, unusual compound choices, most stops and rare strategy sequences.
- A compact whole-grid compound/stint timeline, grouped by strategy when useful.
- A playful race-specific headline rather than generic explanatory prose.

## Free prediction ideas

Possible points/badges game, with no cash value:

- Most above the Elo + qualifying finish expectation (“beat the algorithm”).
- Biggest qualifying/grid-to-finish recovery, with the starting measure explicit.
- A podium finisher from outside the pre-race Elo top five.
- Compound usage, longest stint, most stops or an unusual compound sequence.
- Race-event bingo, once reliable event data is available.

The first ideas can build on existing result/rating data; tyre and event picks
need new feeds. Any later game needs unambiguous questions, a lock deadline,
missing-data handling and reproducible scoring before release.

A winner's prize pot was also floated. No format, funding or rules were agreed;
it remains a separate undecided idea, not part of the free-prediction proposal.

## Executed strategy and pit battles

- Show compound order, stint length and stop laps for every driver. Describe what
  happened, not the team's intent or proof that a strategy was optimal.
- Compare rivals across their complete pit cycle: gap before the first stop,
  corresponding stops, gap/order after both have stopped and where time changed.
- Undercut candidate: the trailing driver pits first and emerges ahead after the
  rival stops. Overcut candidate: the trailing driver stays out longer and emerges
  ahead after their own stop.
- Use the actual pairwise pit-cycle window, not a universal fixed lap interval.
  Compare aligned race laps/timing points, including both drivers' in/out laps.
- Flag safety cars/VSC, red flags, weather changes, traffic, on-track passes,
  penalties, slow stops, retirements and mismatched stop cycles as possible
  confounders. Show high-confidence, mixed-cause or inconclusive cases rather than
  forcing a strategy verdict.
- Validate against manually reviewed ordinary and disrupted races; measure both
  detection precision and how many battles can be assessed before claiming reliability.

## Pace curves and estimated opportunity windows

- Plot recorded lap-time dots, a fitted driver/stint pace curve and a short-horizon
  projection with an uncertainty band; mark stops and race-control interruptions.
- Model compound and tyre age alongside race progression and conditions. Tyre age
  and fuel burn change together: a raw stint slope is not pure tyre degradation,
  and the available feeds do not give us measured fuel loads.
- Fit normal racing pace separately from pit laps, warm-up and neutralised periods;
  account for or flag traffic. Avoid unsupported extrapolation from short stints.
- Compare “stay out” with “pit now” over the same horizon, including pit loss,
  warm-up, fresh-tyre pace, rejoining traffic and assumptions about the rival's stop.
  Accumulated time/gap changes matter, not just where two pace curves intersect.
- Keep observed pit battles, fitted hindsight analysis and hypothetical opportunity
  windows clearly distinct. Do not present a modelled alternative as fact.
- Start with dry, green-flag, short-horizon forecasts. Freeze inputs at each lap and
  test on later laps/races without future-data leakage; compare against simply
  continuing recent pace and check uncertainty-band coverage.

## Data and implementation boundary for later

At the time of this discussion, the app did not store the required lap, pit or
tyre-stint feeds. OpenF1 documents recorded lap/sector durations, tyre compound and
starting age, pit visits, intervals, weather and race-control messages. Historical
access starts in 2023; availability must still be checked per session.
[OpenF1 documentation](https://openf1.org/docs/)

Recorded durations with millisecond precision do not make every timestamp exact:
OpenF1 labels lap-start timestamps approximate, and interval updates are sampled.
Do not invent precision from interpolation or assume every pit visit changed tyres.
Distinguish pit-lane duration from stationary stop time and from modelled time lost
relative to staying on track.

If these ideas are revived, begin with a bounded one-race pilot and stored/cached
analysis, not provider requests during page rendering. Keep enrichment separate
from classification, Elo and fantasy settlement. See the existing
[data expansion plan](race-analysis.md#proposed-integration-boundary) for identity
validation, source coverage and safe import boundaries. No new integration or
computation was implemented by bookmarking these ideas.
