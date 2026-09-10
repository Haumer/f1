# Race debriefs and data expansion

Implemented and investigated on 2026-09-10. Coverage observations below are from
the **local development database**, not an audit of production.

## What is available now

Every race page with stored main-race results renders a debrief at
`/races/:id#race-analysis`. Upcoming races retain the existing preview.

`RaceAnalysis` is a read-only service. Its separate `RaceExpectations` model learns
from earlier races; it never changes Elo or fantasy settlement. No migrations,
external API requests, paid services or Elo recalculation are required. Derived
model profiles are cached by a digest of their actual input data, so source
corrections invalidate the cache even if an Elo replay did not touch timestamps.

History and coverage queries explicitly preload qualifying, race results and
statuses in separate bounded queries. Using `includes` alongside the filtering
join caused a qualifying × results cross-product: about 53,000 joined rows for
the local Abu Dhabi sample. The separate loader preserves model inputs while
reducing local history loading from about 4,000 ms to 155–177 ms. Repeat local
debrief responses fell from about four seconds to 0.3 seconds with development
caching still disabled. The model cache does not skip history loading; production
latency must be checked after deployment before deciding on a persisted report.

The report contains:

- Top 3 / Flop 3: the largest signed expectation gaps among assessable classified
  finishers, with Elo rank, qualifying, estimated finish and actual finish on each
  card. These are model comparisons, not driver-skill or blame rankings.
- A sortable **entire-grid** table: pre-race Elo rank/value, qualifying, estimated
  finish with empirical error range, actual result and places above/below estimate.
  Grid differences are flagged alongside qualifying, not used as a replacement.
- An exploratory historical check comparing Elo + qualifying with separately
  fitted Elo-only and qualifying-only baselines on identical held-out races.
- Largest positive/negative Elo changes and largest valid grid-to-finish gain,
  as supporting context beneath the expectation comparison.
- Race-specific two-driver constructor comparisons, with retirement context.
- Qualifying gaps from the latest segment for which both teammates have valid
  times; never a Q1-to-Q3 comparison.
- Top-five championship standings and position movement from the previous
  non-cancelled round in the same season, where its snapshot exists.
- Aggregate scored fantasy-pick count, best score and mean, without player names,
  profiles, portfolios or holdings.
- Coverage counts and a visible explanation of limitations.

No pre-race rating is substituted with a driver's current rating. Missing ratings
are not zero. If any stored entrant lacks a valid pre-race rating, field Elo ranks
are withheld. Missing qualifying prevents that driver's estimate, not their table
row. Actual results never enter the expectation calculation, even as a fallback.
Missing actual order prevents a performance verdict but not an otherwise valid
estimate. Available individual Elo changes can still be shown.

Grid values of zero or null are excluded from grid gains. Only finished/lapped
results enter place-gain comparisons; retirements, DNS, DNQ and DSQ remain status
labels. Elo itself still uses the stored result order, including retirements.
Nothing here measures overtaking, car-adjusted skill, strategy quality or blame.

## Top 3 / Flop 3 and sharing

Both leaderboards use the same `expected - actual` gap as the full-grid table.
Top 3 selects positive gaps, largest first; Flop 3 selects negative gaps, most
negative first. Exclude DNFs, missing estimates/orders and gaps rounding to 0.0
at the displayed one-decimal precision. Never pad a list to three using drivers
from the other side. Exact ties use driver ID for stable ordering. These are not
significance rankings: a listed driver can still be inside the usual error band.

The race page's **Share this debrief** panel provides a public, canonical deep
link, clipboard copying with a selectable-link fallback, native sharing where
supported, and a preview-card link. It works without an account and shares no
user-specific data or incoming tracking parameters. With JavaScript disabled,
the details panel and manual link still work. Nothing is automatically posted.

Race-specific Open Graph/Twitter metadata points to a 1200×630 PNG at
`/races/:id/analysis/og.png`. Its payload comes from the same leaderboard methods
as the page. Cards include assessment coverage and the experimental-model caveat;
missing-data races explicitly show unavailable rankings. Upcoming races keep the
default preview metadata and have no debrief PNG.

Rendering uses the existing prediction-image runtime dependency, ImageMagick
(`magick`, or `convert` on older installs). No new API, browser process, subscription
or image-generation service is involved. The PNG bytes are cached for one day
under a content fingerprint, with a five-minute public HTTP cache and conditional
ETags. The metadata URL is versioned by the payload. Corrected results, names or
model estimates refresh it even when `Race#updated_at` is unchanged. Bump
`RaceAnalysisShare::VERSION` for rendering-only changes. Platform-side preview
caches may take longer to refresh after deployment.

## Elo + qualifying model (v1)

For a field of `N` stored entrants, calculate:

```text
E = (pre-race Elo rank - 1) / (N - 1)
Q = (qualifying position - 1) / (N - 1)
F = (actual finishing position - 1) / (N - 1)

estimated F = intercept + elo_weight × E + qualifying_weight × Q
expected finish = 1 + clamp(estimated F, 0, 1) × (N - 1)
above expectation = expected finish - actual finish
```

Ranks tied on Elo share the midpoint of their rank range. The rank is calculated
over the whole stored field, not just eventual finishers. The fitted coefficients
are learned, not a manually selected 50/50 blend. Slopes are constrained to be
non-negative, and estimates stay within the field. Estimates are conditional
averages, not unique positions assigned to a predicted complete finishing order.

Training uses only races on strictly earlier dates within a rolling ten-year
window, with at least 20 races and 200 paired classified finishes. The target
is **finish position conditional on that driver finishing/classifying**, including
lapped finishers. DNFs, DNS, DNQ and DSQ are excluded as training targets, retained
in the displayed grid, and receive no performance verdict. Other drivers' normal
historical attrition is still reflected in the learned finishing positions.

`Dataset` pairs actual qualifying with race entries and stored pre-race Elo.
`Regression` fits the two-input model and the one-input comparison models.
`Backtest` holds out entire races in chronological order; each fit sees only older
events. `Report` projects those pre-race expectations onto all current entries.
This follows the rolling-origin evaluation principle of never learning from the
held-out race or its future. [Forecasting: Principles and Practice](https://otexts.com/fpp3/tscv.html)

The error guide is the 80th percentile of absolute, field-normalised errors on
earlier held-out races from the last ten years. Scale it to the target field,
then round bounds outward and clip to P1–PN. Display it only after at least five
checked races and 100 checked finishes. "In range" means the actual position lies
inside those displayed bounds; otherwise use "Above range" or "Below range".
This is **not a calibrated 80% probability for a particular driver**. It pools
different drivers and races, omits coefficient uncertainty, and needs more data
before more specific conditional intervals are defensible.

### Reproducible local check

No writes or imports:

```sh
AS_OF=2026-09-10 bundle exec rails f1:expectations_backtest
```

Observed on 2026-09-10, using the local archive:

| Earlier-race rolling check | Races | Classified finishes | Combined MAE | Qualifying-only MAE | Elo-only MAE |
| --- | ---: | ---: | ---: | ---: | ---: |
| All eligible historical checks after the minimum training period | 101 | 1,600 | 2.319 | 2.483 | 2.833 |
| Checks in the most recent ten-year window | 39 | 650 | 2.213 | 2.386 | 2.715 |

MAE is average absolute error in finishing places. These are exploratory results
on patchy, retrospectively corrected local records, not a guarantee of live
forecasting accuracy. Model/window choices were investigated on this archive;
there is no separate pristine final test set. The app recomputes the figures
using only data earlier than each displayed race, so page figures can differ.

The current ten-year fit has 39 races / 650 classified finishes and coefficients
approximately `0.0462 + 0.2974 × E + 0.4739 × Q`. For Elo rank 5 and qualifying P10
in a 22-car field, it estimates P7.4: a P6 finish is about 1.4 places ahead, within
its broad empirical range—not automatically an exceptional recovery.

For a concrete stored race, Abu Dhabi 2025 (`/races/1125#race-analysis`), a model
fit strictly before that race estimates Hamilton at P10.6 after qualifying P16;
P8 is inside the P7–P14 error range. Hülkenberg's P9 from Q18 beats his P14.3
estimate and P11–P18 range. These are local-data calculations, not causal claims
about either drive.

### Limits and next model improvements

- Qualifying position, not actual starting grid, is an input. Grid penalties or
  unnumbered starts can materially change expectations and are visibly flagged.
- Elo rank loses rating-gap magnitude; test field-relative Elo strength as an
  additional predictor before changing this version.
- No circuit, tyre, weather, safety-car, penalty or strategy adjustment is fitted.
- Historical qualifying is sparse. More paired recent races, event identity
  checks, and a live frozen pre-race validation set come before more model
  complexity. Fit circuit effects or local error bands only with enough support.
- This model does not predict retirement probabilities. A future unconditional
  race forecast needs a separate reliability treatment and evaluation target.

## Coverage findings and the first repair

The debrief layout works for every race with results, but expectation rankings
require valid qualifying per entrant, a complete seedable pre-race Elo field,
and at least 20 earlier eligible races / 200 classified finishes within ten years.
The error range additionally needs five earlier checked races / 100 finishes;
its absence does not prevent point estimates or Top/Flop rankings.

No manual precomputation or Elo rerun is needed. Model fitting/backtesting is
on-demand and cached; leaderboards are a small sort of that report. The gap is
data availability, not a missing computation job. Backfilling qualifying updates
affected reports automatically. It also improves training inputs for later races,
so their estimates can legitimately change after an archive correction.

Read-only, repeatable prerequisite audit (does not fit every historical model):

```sh
AS_OF=2026-09-10 bundle exec rails f1:expectations_coverage
AS_OF=2026-09-10 YEAR=2026 DETAILS=1 bundle exec rails f1:expectations_coverage
```

Local snapshot on 2026-09-10; these are stored races, not verified production
coverage. Missing-prerequisite categories in the task overlap.

| Scope | Races with results | Full-grid estimates | Partial estimates | No estimates |
| --- | ---: | ---: | ---: | ---: |
| Entire local archive | 1,162 | 92 | 9 | 1,061 |
| 2026 to September 10 | 13 | 1 | 1 | 11 |

In 2026, round 1 supports estimates for 19/22 entries (14 assessable finishers),
round 2 supports 22/22 (15 assessable finishers), and rounds 3–13 lack usable
qualifying inputs. All 13 already have the Elo field and enough earlier history.
Across the archive, 1,054 races lack at least some usable qualifying and 617 lack
enough earlier eligible history; those are overlapping counts. Current qualifying
coverage is sparse, so availability is not guaranteed merely by choosing a year
after the first recorded qualifying session. No backfill was run in this pass.

The latest five stored races each have 22 main-race results and all 22 before/after
driver Elo snapshots, but **zero qualifying rows**. The latest has 20 positive grid
values. Overall, 2,552 qualifying rows exist, spanning 1996–2026; this does not mean
every race in that interval is covered.

The existing qualifying path has several ways to leave holes:

1. `SeasonSync#sync_session_results` only checks the current weekend and skips any
   race with even one qualifying row.
2. `f1:qualifying_sync` only enqueues sessions in a 2–24-hour post-start window.
3. `QualifyingSyncJob` stops retrying when the fetch returns no data; its three
   retries only address a nonempty partial response.
4. Completeness is based on the season roster, which can include substitutes or
   mid-season driver changes rather than that event's entrants.

These explain how missed or late publication can persist; they do not prove the
cause of every missing race. No production scheduler configuration was inspected.

Recommended next implementation: a bounded qualifying repair job for recent
completed weekends, plus an explicit season backfill. Validate returned circuit,
date and season before writing, paginate, retain existing good data on failed or
partial responses, retry empty results with backoff, and distinguish unavailable
from not-yet-fetched. Use event entrants for coverage rather than the whole season
roster. Do not call the broader full-sync task: qualifying repairs do not need Elo
or fantasy replays. The existing `f1:qualifying YEAR=...` task is a starting point,
but was **not run** in this pass.

Jolpica already exposes qualifying position and optional Q1/Q2/Q3 times through
the endpoint the app uses. It also requires an identifying User-Agent and supports
pagination with a maximum page size of 100. Add those safeguards to the shared
fetching path before a substantial backfill. [Qualifying endpoint](https://github.com/jolpica/jolpica-f1/blob/main/docs/endpoints/qualifying.md),
[API conventions](https://github.com/jolpica/jolpica-f1/blob/main/docs/README.md)

## Expansion options, in priority order

| Area | Source and documented coverage | Useful addition | Important limit |
| --- | --- | --- | --- |
| Qualifying | Existing Jolpica importer; audit availability per event | Same-segment teammate pace and qualifying-to-grid differences | Qualifying position is not the final grid after penalties |
| Lap timing | Jolpica, from 1996 | Lap-position history and measured lap-time distributions | Position changes include pit cycles; raw averages are not clean race pace |
| Pit stops | Jolpica, from 2011 | Stop counts, stop laps and recorded duration | Do not label the duration as stationary tyre-change time |
| Tyres and race context | OpenF1, historical sessions from 2023 | Compound/stint timeline, weather and race-control annotations | Coverage and null fields vary by session |
| Detailed telemetry | FastF1, a separate Python analysis option | Sector and telemetry investigations | More operational work than adding JSON ingestion to Rails |

Jolpica documents lap records with driver, lap, position and time, and a separate
pit-stop endpoint. Its unauthenticated limits are currently four requests/second
and 500/hour; use a shared limiter, caching and resumable paginated imports.
[Laps](https://github.com/jolpica/jolpica-f1/blob/main/docs/endpoints/laps.md),
[Pit stops](https://github.com/jolpica/jolpica-f1/blob/main/docs/endpoints/pitstops.md),
[Rate limits](https://github.com/jolpica/jolpica-f1/blob/main/docs/rate_limits.md)

OpenF1's free historical access starts in 2023, requires no authentication and is
limited to three requests/second and 30/minute. Sessions become historical 30
minutes after they end; live access is a separate paid offering. The provider
describes educational, research and non-commercial fan uses; review suitability
and attribution before integrating, especially if monetisation changes.
[Access and usage guidance](https://openf1.org/)

For OpenF1 pit timing, prefer `lane_duration`; `pit_duration` is deprecated for
removal at the end of 2026. `stop_duration` is stationary time and is only available
from the 2024 US GP onward. Race control includes flags/messages, and stints include
compound and lap ranges. These support timelines, not proof of why a driver won
or lost time. [API reference](https://openf1.org/docs/)

FastF1 exposes timing, telemetry, tyre and weather data through Python/Pandas and
includes request caching. It is worth considering for deeper offline work; my
recommendation for this Rails app is to start with bounded JSON imports instead
of adding a second runtime immediately. No FastF1 package was installed or tested.
[FastF1 introduction](https://github.com/theOehrly/Fast-F1/blob/master/docs/index.rst)

## Read-only source checks

The following historical API probes succeeded on 2026-09-10. Counts describe this
sample only, not global completeness. No returned data was imported.

| Probe | Observed response |
| --- | --- |
| Jolpica `2024/16/qualifying.json?limit=100` | Italian GP, 2024-09-01; 20 qualifying entries |
| Jolpica `2024/16/laps.json?limit=1` | Same event; reported total 1,008 driver-lap timing records |
| Jolpica `2024/16/pitstops.json?limit=1` | Same event; reported total 30 stops |
| OpenF1 Italian race sessions in 2024 | Both Imola and Monza returned; Monza session key 9590 |
| OpenF1 stints, session 9590, driver 16 | Two stints; compound and lap boundaries present |
| OpenF1 pit, session 9590, driver 16 | One stop; lane duration 24.5 seconds, stationary duration null |
| OpenF1 race control, session 9590 | 61 messages, including non-incident operational messages |

## Proposed integration boundary

Keep enrichment independent of classification, Elo and fantasy settlement:

1. Resolve a source session by year, circuit, date and session type. Persist its
   provider ID; do not join by country, round or driver number alone. A driver
   number must be resolved within the matched session. Flag ambiguous matches.
2. Import after the provider's historical-data window, in a bounded background
   job with a shared rate budget, timeouts, backoff and a resumable cursor.
3. Store typed `RaceLap`, `RacePitStop`, `RaceStint` and `RaceControlEvent` records
   only as their features are introduced. Keep source, fetch time, units and a
   version/content signature alongside an import status and coverage report.
4. Upsert with event-scoped unique keys. Publish enrichment after complete
   pagination/validation; a failed refresh must not erase a good prior dataset.
5. Extend this report with a clearly labelled section for each available dataset.
   Keep missing enrichment from blocking the baseline debrief or settling fantasy.

For a pace comparison, first identify pit in/out laps and interrupted/neutralised
periods, compare like tyre/stint windows, publish excluded-lap rules and sample
sizes, and describe results as observed pace—not a counterfactual result. Do not
attempt an unqualified "strategy cost X seconds" headline from lap times alone.

**Recommended next slice:** qualifying repair first, then a one-race lap/pit/stint
pilot with an annotated timeline. Validate against several ordinary and disrupted
weekends before bulk historical ingestion. No new external integration, scheduler
change, subscription or production backfill has been enabled by this feature.
