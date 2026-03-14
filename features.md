# Feature Ideas

## 1. Race Predictions

Users predict the finishing order before each race. Two input modes:

### Drag & Drop
- Full grid shown as a sortable list
- Drag drivers into predicted finishing order
- Desktop-first, works on mobile with touch drag

### Tinder Mode
- Pairwise comparisons: "Who finishes higher, A or B?"
- System builds a ranking from the pairwise results (merge sort style)
- Faster on mobile, lower cognitive load
- ~80 comparisons for 20 drivers (n log n)

### Scoring
- Points based on accuracy vs actual result
- Exact position match = max points
- Partial credit for being close (e.g. within 2 positions)
- Bonus for predicting podium correctly
- Leaderboard across season

### Guest Picks (Session-Based)
- Remove `authenticate_user!` from `edit` action (keep on `update`)
- Anyone can visit `/picks/edit` and build picks client-side (Stimulus works without auth)
- On "Save": if not logged in, stash picks JSON in `session[:pending_picks]` + `session[:pending_picks_race_id]`
- Redirect to signup/login with flash: "Sign up to save your picks!"
- After login/signup: Devise `after_sign_in_path_for` checks session for pending picks
- Auto-creates `RacePick` from session data, clears session, redirects to portfolio
- No guest user gem, no orphaned records, no cleanup needed
- Session is just a JSON string — lightweight

### Scoring
- Points based on accuracy vs actual result
- Exact position match = max points
- Partial credit for being close (e.g. within 2 positions)
- Bonus for predicting podium correctly
- Leaderboard across season

### Considerations
- Lock predictions before race start (use `race.starts_at`)
- Allow editing until lock
- Show predictions vs results after race with visual diff
- Could tie into fantasy portfolio (bonus cash for accurate predictions)

---

## 2. Live Race Data

Real-time race tracking with animated visualizations.

### Data Source
- OpenF1 API: live position tracking, lap times, stints, pit stops
- Polling interval: every 5-10 seconds during race
- WebSocket or Turbo Streams for push updates to browser

### Visualizations
- **Position tower**: Animated driver list that reorders in real-time as positions change
- **Gap chart**: Time gaps between drivers, animated bars
- **Track map**: Driver positions on circuit outline (SVG), moving dots
- **Lap time chart**: Rolling lap times per driver, highlight fastest lap
- **Tire strategy**: Visual stint bars showing compound + lap count

### Animation
- Smooth CSS transitions on position changes (swap animation)
- Color-coded by constructor
- Highlight overtakes with flash/pulse effect
- Pit stop indicator animation

### Considerations
- OpenF1 has live data but can be incomplete (see memory notes)
- Fallback to static results if live feed fails
- Cache aggressively to avoid API rate limits
- Mobile-responsive layout (stack tower + one chart)
- Record live data for post-race replay mode
