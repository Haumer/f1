# F1 Elo Public Launch

This is the zero-budget launch plan. The useful angle is not “another F1 site”; it is an interactive,
open-source rating history covering every classified driver and constructor result since 1950.

## Before announcing it

- Deploy the reviewed release and run the constructor Elo recalculation documented in the README.
- Set `APP_HOST=f1elo.com`. Set `GOOGLE_ANALYTICS_ID` only if optional Google Analytics is wanted;
  visitors are asked before its script loads.
- Check `/`, `/elo`, `/robots.txt`, and `/sitemap.xml` from a signed-out browser, and confirm that
  `https://www.f1elo.com/elo` permanently redirects to `https://f1elo.com/elo`.
- Check one driver, constructor, race, season, circuit, and share-preview URL on a phone.
- Confirm the interface still reads well with the open web/system type stack; proprietary Formula 1
  font binaries are deliberately excluded from the public source release.
- Have a human review the Terms and Impressum. The code makes analytics more conservative, but code
  review is not legal review.

## Free discovery setup

1. Add and verify the domain in [Google Search Console](https://support.google.com/webmasters/answer/10267942),
   submit `https://f1elo.com/sitemap.xml`, and inspect the home page plus `/elo`. Google documents the
   submission and error workflow in its [Sitemaps report guide](https://support.google.com/webmasters/answer/7451001).
2. On GitHub, set the repository description to the one-line pitch below, set the website to
   `https://f1elo.com`, and add topics such as `formula-1`, `f1`, `elo-rating`, `ruby-on-rails`,
   `sports-analytics`, `open-data`, and `fantasy-sports`. GitHub says topics improve repository
   discovery: [repository topics](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics).
3. Upload `public/og-image.png` as the GitHub social preview. It is a solid-background 1200×630 PNG
   under 1 MB, within GitHub's documented format and minimum-size guidance:
   [social preview](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview).

## Announcement order

1. Share one genuinely interesting result in F1 communities where self-promotion is allowed: an
   unexpected all-time peak, a driver comparison across eras, or a constructor lineage. Link to the
   exact result page, disclose that it is your project, and participate in the discussion.
2. Share the implementation with Rails and open-source communities: historical ingestion, the
   pairwise Elo normalization, and the test/CI approach are stronger hooks there than fantasy play.
3. Consider a Show HN only when the deployed app is stable and usable without signup. The official
   [Show HN guidelines](https://news.ycombinator.com/showhn.html) favor things people can try and a
   personal explanation of how and why they were built. Write that explanation yourself and do not
   solicit votes.
4. After each race, publish one chart or surprising Elo movement and deep-link to the race or driver.
   A useful recurring result is more sustainable than repeatedly posting the homepage.

## Copy kit

One-line pitch:

> F1 Elo rates every Formula 1 driver and constructor from 1950 to today, with interactive histories,
> cross-era comparisons, race picks, and an open-source Rails implementation.

Short community post skeleton:

> I built F1 Elo to answer a question championship points cannot: how strong was a result relative to
> the field? Every classified finisher is compared pairwise after each race, with ratings carried across
> seasons. The full history, methodology, and source are public. This week’s result that surprised me:
> [write one specific, current observation]. I would especially value feedback on [one real question].

Do not paste the same copy everywhere. Lead with the result most relevant to each community and answer
comments while the post is active.

## Measure without paying

- Search Console: indexed pages, impressions, queries, and click-through rate.
- Built-in aggregate analytics: landing paths and returning traffic, without analytics cookies or
  account-linked browsing histories.
- Product signals: completed head-to-head sessions, submitted race picks, new accounts, and returning
  players after the next race.

Review these after two race weekends. Keep the channels that produce engaged return visits; stop posting
to channels that only create a one-day spike.
