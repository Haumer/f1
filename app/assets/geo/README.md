# world.geo.json

Country outlines for the circuit calendar map (`circuits#index`).

Source: [Natural Earth](https://www.naturalearthdata.com) `ne_110m_admin_0_countries`,
via [nvkelso/natural-earth-vector](https://github.com/nvkelso/natural-earth-vector).
Natural Earth is in the public domain — no attribution required, given anyway.

Reduced from 839 KB to 160 KB (≈48 KB gzipped) by:

- rounding coordinates to 2 decimal places (~1.1 km, well under a pixel at world zoom)
- dropping consecutive duplicate points left behind by that rounding
- keeping only the `name` property
- dropping Antarctica, which is the single largest polygon in the file and has
  never hosted a Grand Prix

Regenerate with `bin/rails geo:world` if the outlines ever need updating.
