# Walkthrough project notes — F1 Elo

Ground rules learned on the first run (2026-08-30). Read this before any `/walkthrough`.

## Dev server
- `bin/rails s -p 3456`. Comes up in ~1s. Log to the session scratchpad, not the repo.
- Console on EVERY page shows 1 error + 2 warnings at baseline:
  - `zrender@5.4.4/lib/` 404 (see tour bug 1 — a dead importmap pin)
  - manifest icon purpose warning, `apple-mobile-web-app-capable` deprecation
  Treat >3 console entries as page-specific and worth investigating.

## Accounts
- Signup is `/users/sign_up`, fields `user[username]`, `user[email]`, `user[password]`,
  and a `user[terms_accepted]` checkbox that must be checked.
- No email confirmation — signup redirects straight to `/fantasy/u/:username`.
- Standing test persona: **hist_margit** / margit.osterlund@example.test / `Chicane!1958` (User id=15).
  Supports Alpine F1 Team for 2026.

## URLs / routing gotchas
- Constructors use a **slug**, not an id: `/constructors/alpine`, not `/constructors/211`.
  `Constructor#to_param` returns `constructor_ref`. `/constructors/<id>` 404s.
- Drivers use numeric ids.

## Confirm dialogs
- **Not `window.confirm`.** `app/javascript/application.js:16` overrides Turbo's confirm with
  **SweetAlert2**. Pattern: click → wait ~1.5s → read `.swal2-popup` text → click `.swal2-confirm`.
- SweetAlert2 always renders a hidden `.swal2-deny` ("No") button. Check `offsetParent`/`display`
  before reporting a stray third button — only Confirm and Cancel are visible.
- Mutating links are `<a data-turbo-method="post">`, **not** `<form>`. Selectors looking for
  `button`/`input[type=submit]` will miss them.

## Verifying state outside the UI
- `bin/rails runner '...'` for dev.
- Production: `heroku run --no-tty rails c -a f1-elo` (per standing project rule, prefer `rails c`).
  Pipe with `echo '...; exit' | heroku run --no-tty rails c -a f1-elo`.

## Reading results
- **Never read numbers off a screenshot.** Two figures were misread from full-page renders this run
  (Graham Hill's 2,601 as 2,681; Antonelli's 510 as 512). Always pull values from the DOM.
- Charts are echarts on **canvas** — there are no `<text>` nodes to query. Read chart config from
  the `Graphs::*` service in `app/services/graphs/` instead.

## Data shape (2026 dataset)
- 865 drivers, 1171 races (prod 1172), 77 seasons (1950–2026), 76 decided championships.
- 2026 is mid-season: 22 races on the calendar, **11 scored**. Anything iterating a full season's
  races must handle unscored future rounds — this is the cause of tour bug 13.
- `Country`/`DriverCountry` are **empty in dev and prod** — all flags are missing site-wide.
- `Driver#skill` is NULL for all 865 drivers, so `Driver.elite` matches nothing.
