# Gemini art prompt pack — F1 Elo

Small UI icons are now hand-authored SVG (`app/helpers/icons_helper.rb`, 40
glyphs). Those should stay vector: they need to be crisp at 16px, take their
colour from `currentColor` so the per-page accent flows through them, and cost
nothing to ship. Generated raster art can't do any of that.

What generated art *is* right for is the larger illustrative pieces — the ones
that are looked at rather than read. Those are listed below, each with a
ready-to-paste prompt and the exact spec for where the file goes.

## House style — prepend to every prompt

> Flat vector illustration, no photorealism, no 3D render, no gradients meshes.
> Dark background #0a0a0f. Limited palette: one dominant accent plus warm
> neutrals. Geometric construction — straight lines and precise arcs, the
> language of a Formula 1 timing screen and technical drawings, not soft
> friendly rounded shapes. Subtle film grain. No text, no lettering, no numbers,
> no logos, no real team liveries, no recognisable drivers or trademarks.
> Centred subject with generous negative space around it.

The trademark line matters: the site's footer already disclaims affiliation, and
generated art that leans on real liveries would undercut that.

---

## 1. Achievement badge art (25 pieces) — highest value

**Why generated:** the 25 achievements currently share ~12 line glyphs
differentiated only by tier colour. Distinct medallion art per achievement is
the single biggest "this feels made, not assembled" upgrade in the app, and
medallions are exactly the kind of ornamental object that hand-drawn SVG is slow
at and generation is fast at.

**Spec**
- 512×512 PNG, transparent background
- Save to `app/assets/images/achievements/<key>.png` — keys are the hash keys in
  `app/models/fantasy_achievement.rb` and `fantasy_stock_achievement.rb`
- Render via `image_tag "achievements/#{key}.png"` inside
  `.fantasy-achievement-icon`, falling back to `ui_icon defn[:glyph]` when the
  file is missing, so a partial set still ships

**Per-tier framing** (append to the house style):

| Tier | Append |
|---|---|
| bronze | `A circular medallion in weathered bronze (#d4844a), thin bevelled rim, low sheen.` |
| silver | `A circular medallion in brushed silver (#a0a0b0), thin bevelled rim, cool highlights.` |
| gold | `A circular medallion in polished gold (#f0c850), thin bevelled rim, warm glow.` |
| legendary | `A circular medallion in iridescent violet-to-cyan (#c77dff to #7fd4e8), faint prismatic edge, unmistakably rarer than the others.` |

**Subject line** — append the achievement's own idea. Examples:

- `first_profit` — *A single upward arrow breaking through a horizontal baseline.*
- `profit_10x` — *A stylised rocket trajectory arcing off the top of the medallion.*
- `streak_3` — *Three chevrons stacked in ascending order, each brighter than the last.*
- `top_1` — *A chequered flag furling around a laurel.*
- `first_short` — *A downward arrow with a small stylised bear silhouette formed from straight edges.*
- `max_positions` — *A grid of twelve small filled squares, all lit.*
- `early_adopter` — *A seedling rendered as three straight-edged leaves.*
- `profitable_short` — *A downward arrow crossing a rising line, the downward one lit.*

Generate one image per key; keep the framing line identical within a tier so the
set reads as one collection.

---

## 2. Empty-state illustrations (4 pieces)

**Why generated:** empty states are the first thing a new player sees and are
currently a single grey glyph over a line of text.

**Spec:** 800×500 PNG, transparent background, sits above the existing
`.empty-state` heading. Save to `app/assets/images/empty/<name>.png`.

| File | Prompt subject |
|---|---|
| `no-positions.png` | *An empty pit garage bay seen head-on, floor markings and a bare tyre rack, one overhead light on. Nothing parked in it.* |
| `no-picks.png` | *A blank starting grid seen from above, the painted box outlines empty, start lights unlit overhead.* |
| `no-cards.png` | *An open empty card sleeve album, slots outlined but unfilled, one slot faintly glowing.* |
| `no-portfolios.png` | *An empty podium, three tiers, no figures, a single spotlight on the top step.* |

---

## 3. Open Graph share images (2 pieces)

**Why generated:** `public/og-image.png` is currently one static fallback used
for every page, so every link the site shares looks identical. Per-surface art
gives the encyclopedia and the fantasy game distinct cards.

**Spec:** 1200×630 PNG, opaque #0a0a0f background. Leave the **left 55% clear**
— the existing dynamic OG pipeline (`predictions#og_image`) overlays text there.

| File | Prompt subject |
|---|---|
| `public/og-elo.png` | *A rating curve climbing across the right half of the frame over a faint circuit outline, telemetry-trace styling, deep orange accent.* |
| `public/og-fantasy.png` | *An abstract candlestick chart on the right half, bars rendered as pit-lane markings, green and red accents on near-black.* |

---

## Before wiring anything in

Per your standing rule, nothing here should be written into the app or the
database until you've reviewed the generated files. The suggested loop:

1. Generate a tier at a time (bronze first — 8 of the 25).
2. Drop them in `app/assets/images/achievements/`.
3. I'll wire the `image_tag` + `ui_icon` fallback and show you the grid rendered
   at real size, on both breakpoints, before we go further.

The fallback ordering means a half-finished set never looks broken: any
achievement without a PNG keeps its current vector glyph.
