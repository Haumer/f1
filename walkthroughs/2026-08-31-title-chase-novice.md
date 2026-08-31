# Walkthrough — Title Chase, as a stats-literate F1 novice — 2026-08-31

**Persona:** reads charts for a living, has never watched a Grand Prix. Signed out, arriving cold.
**URL:** /stats/title_chase (also /stats/title_chase/2024 for the finished-season state)
**Question asked:** does this page fulfil its job?

## Regression check vs 2026-08-30 run
- BUG 13 (all five points lines collapsing to zero at R11) — **fixed**, lines now stop at the last scored round.
- The three-column "avg pts per race" matrix — **replaced** with position language.

## Verdict

It answers "who is winning" and, now, "what would have to happen". It does not
answer "what is being measured", and one headline number actively leads a
careful reader to a wrong figure. The retrospective mode for finished seasons
is the strongest part of the page and the live mode is the weaker one.

## Findings, worst first

### 1. The headline invites a 72-point error — BLOCKS COMPREHENSION
The page states "11 races remaining" and "MAX PER ROUND 33". The obvious
product is 11 x 33 = **363** points still available. The true figure is **291**,
because only 2 of the 11 remaining rounds carry a sprint. The 72-point gap is
larger than the spread between 1st and 4th. A reader checking whether the
Magic Number (242) is attainable does so against a bound that is wrong by 25%.
Fix: state remaining points directly ("291 still on the table"), or qualify the
33 as applying to 2 of 11 rounds.

### 2. The premise is never stated
Nowhere does the page say that a championship is decided on accumulated points,
or what a win is worth. "25 race + 8 sprint" is the only clue and it is a
sub-label on a stat card. Everything below depends on that premise.

### 3. "Magic Number — 242 — net pts to clinch"
Three problems. "Magic number" is borrowed from American sports and is not
self-describing. "Net" is the wrong word — it is a gross worst-case requirement
for the leader, assuming the best chaser wins everything. And 242 is unanchored:
it only means something against the 291 available, which the page never states.

### 4. "Alive vs eliminated" is a constant column for most of a season — MEASURED
The section is named after a split that does not split. Sampled:
- 2026 at round 11: **21 of 21 challengers "Alive"**
- 2024 finished:    **23 of 23 "Eliminated"**
Computing the first mathematical elimination across three seasons:
| Season | Rounds | First elimination | Badge constant for |
|---|---|---|---|
| 2021 | 22 | round 14 | 59% of season |
| 2024 | 24 | round 14 | 54% of season |
| 2025 | 24 | round 14 | 54% of season |
It is a binary that is degenerate for the first ~55% of every season and
near-saturated within a few rounds of the end. Its informative window is roughly
rounds 14-21. A continuous measure (title probability) would carry information
across the whole season; this one carries it for about a third.

### 5. "What each challenger needs" does not degrade — my own table, fairly caught
21 rows. The distribution of answers:
`P7 or worse` x11, `P6` x3, `P3` x3, `P2` x2, `P4` x1, `P5` x1.
**More than half the table is the same repeated value**, for drivers on 0-10
points who are not challengers in any meaningful sense. It inherits its row set
from the vacuous "alive" flag (finding 4). Should cut to genuine contenders and
collapse the rest to a line ("11 others: mathematically alive, realistically not").

### 6. "race" / "round" / "sprint" used interchangeably, none defined
"11 races remaining · 2 sprints" (hero) · "MAX PER ROUND" (stat) · "Gap to
leader, race by race" (chart) · "P1 in all 11 remaining rounds, plus 2 sprints"
(footnote — the "plus" implies 13 separate events). A newcomer cannot tell
whether a sprint is a race, or whether the 2 sprints are inside or on top of
the 11. This ambiguity is the direct cause of finding 1.

### 7. No tooltips on the standings headers
"Pts / Max / Behind" have no `title` attributes. "Max" showing 291 for a driver
on 0 points reads as "most they have scored" rather than "most they could
finish on".

## What genuinely works — do not regress these
- **Finished-season mode is excellent.** "Champion / Clinched: Round 22 (Las
  Vegas · 2 races left) / Margin: +63 ahead of Norris", with the chart section
  retitled "When the title was won". Clear to a newcomer with no F1 knowledge.
- **Chart captions state the things charts usually omit**: "Top 5 by current
  standings" names the population, and "Closer to top = closer in the title
  race" names the direction of good. Better than most dashboards.
- **Gap-to-leader is the right chart** for the question the page asks — a
  difference series rather than two levels the reader must subtract by eye.
- The needs table's core idea (ceiling, then what the leader must do) is sound;
  it is the row set and the jargon that let it down, not the arithmetic.

## Suggested order
1. Replace "Max per round 33" with remaining points available (291) — kills finding 1 and anchors finding 3.
2. One explanatory sentence under the h1 covering the premise and the terms (findings 2, 6).
3. Cut the needs table to real contenders (finding 5).
4. Title probability to replace the binary (finding 4) — the simulation work already scoped.
