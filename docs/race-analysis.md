# Race debriefs and data expansion

Implemented and investigated on 2026-09-10. Coverage observations below are from
the **local development database**, not an audit of production.

## What is available now

Every race page with stored main-race results renders a debrief at
`/races/:id#race-analysis`. Upcoming races retain the existing preview.

`RaceAnalysis` is a read-only service, not a new Elo model or an AI-generated
article. It reads stored race snapshots on each request; no migrations, external
API requests, background generation, paid services or Elo recalculation are
required. Corrected inputs appear on the next page load.

The report contains:

- Largest positive/negative Elo changes and largest valid grid-to-finish gain.
- A comparison of pre-race Elo order with finishing position, showing up to eight
  largest absolute departures among classified finishers. Equal ratings share the
  midpoint of their rank range. This is an ordinal baseline, **not a calibrated
  finishing prediction**.
- Race-specific two-driver constructor comparisons, with retirement context.
- Qualifying gaps from the latest segment for which both teammates have valid
  times; never a Q1-to-Q3 comparison.
- Top-five championship standings and position movement from the previous
  non-cancelled round in the same season, where its snapshot exists.
- Aggregate scored fantasy-pick count, best score and mean, without player names,
  profiles, portfolios or holdings.
- Coverage counts and a visible explanation of limitations.

No pre-race rating is substituted with a driver's current rating. Missing ratings
are not zero. If any stored entrant lacks a valid pre-race rating or result order,
the Elo-order comparison is withheld. Available individual Elo changes can still
be shown, explicitly limited to the stored rated results.

Grid values of zero or null are excluded from grid gains. Only finished/lapped
results enter place-gain comparisons; retirements, DNS, DNQ and DSQ remain status
labels. Elo itself still uses the stored result order, including retirements.
Nothing here measures overtaking, car-adjusted skill, strategy quality or blame.

## Coverage findings and the first repair

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
