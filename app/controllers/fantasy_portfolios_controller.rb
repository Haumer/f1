class FantasyPortfoliosController < ApplicationController
  include FantasyPortfolioData
  before_action :authenticate_user!, except: [:combined_leaderboard, :overview, :leaderboard]

  # ═══════════════════════════════════════
  # Username-based pages
  # ═══════════════════════════════════════

  def overview
    load_user_and_season
    return if performed?

    load_portfolio_data
    load_stock_data

    if @portfolio
      @achievements = @portfolio.achievements.order(created_at: :desc)
      if @is_owner
        @next_race = @portfolio.season.next_race || Race.where("date >= ?", Date.current).order(:date).first
      end
    end

    # Stock detail data (inline on overview)
    if @stock_portfolio
      @stock_achievements = @stock_portfolio.achievements.to_a
      if @is_owner
        @next_race ||= @stock_portfolio.season.next_race || Race.where("date >= ?", Date.current).order(:date).first
        @stock_can_trade = @next_race && @stock_portfolio.can_trade?(@next_race)
      end
    end

    # Always resolve next_race for the hero countdown (public profiles too).
    @next_race ||= @season.next_race || Race.where("date >= ?", Date.current).order(:date).first

    # Whether this user has claimed their H2H completion bonus for the current
    # anchor race. Anchor matches HeadToHeadController: next_race || last_race.
    # Owner-only — checklist is not shown on public profiles.
    if @is_owner
      @h2h_anchor_race = @next_race || @season.last_race
      @h2h_done_for_race = @h2h_anchor_race && DriverPreferenceSession
        .where(user_id: @user.id, race_id: @h2h_anchor_race.id)
        .where.not(bonus_awarded_at: nil).exists?
    end

    # Leaderboard rank + delta from the user's two most recent snapshots. Snapshot
    # rank is precomputed by Fantasy::SnapshotPortfolios so this is just a lookup.
    if @portfolio
      last_two = @portfolio.snapshots.joins(:race).order("races.date DESC").limit(2).to_a
      latest = last_two.first
      previous = last_two.second
      if latest&.rank
        @leaderboard_rank = latest.rank
        @leaderboard_rank_delta = previous&.rank ? previous.rank - latest.rank : nil
        peers = FantasySnapshot.where(race_id: latest.race_id)
        @leaderboard_size = peers.count

        # "#3 of 6" says where you are but not whether that's close. The gap to
        # the rank above (or, if you're leading, to the one below) is what makes
        # the position mean something.
        neighbour_rank = @leaderboard_rank > 1 ? @leaderboard_rank - 1 : @leaderboard_rank + 1
        neighbour = peers.find_by(rank: neighbour_rank)
        if neighbour
          @leaderboard_gap = (neighbour.value.to_f - latest.value.to_f).abs.round
          @leaderboard_gap_direction = @leaderboard_rank > 1 ? :behind : :ahead
        end
      end
    end

    # Portfolio composition: long/short counts and team concentration. All derived
    # from already-loaded holdings (no extra queries via prime_active_holdings).
    if @stock_portfolio && @stock_holdings
      @long_count = @stock_holdings.count(&:long?)
      @short_count = @stock_holdings.size - @long_count
      if @stock_holdings.any? && @stock_constructors.is_a?(Hash)
        gross = @stock_holdings.sum { |h| h.entry_price.to_f * h.quantity.to_i }
        if gross > 0
          team_totals = @stock_holdings.group_by { |h| @stock_constructors[h.driver_id]&.name || "—" }
                                        .transform_values { |hs| hs.sum { |h| h.entry_price.to_f * h.quantity.to_i } }
          top_team, top_value = team_totals.max_by { |_, v| v }
          @top_team_name = top_team
          @top_team_pct  = (top_value / gross * 100).round
        end
      end
    end

    # Unified activity feed (credits + cards + achievements). Owner-only — public
    # profiles don't expose individual events. Profile shows a teaser; full feed
    # lives at fantasy_activity_path so the portfolio page stays scannable.
    if @is_owner
      @activity_entries = Fantasy::ActivityFeed.for_user(@user, season: @season, limit: 8)
    end

    # Race picks — upcoming + past
    @race_picks = RacePick.where(user: @user)
                          .joins(race: :season)
                          .where(seasons: { year: @season.year })
                          .includes(race: [:circuit, :season])
                          .order("races.round DESC")

    # Per-pick scorecard summary (total + exact hits) for picks whose race has
    # results. Computed from results via the same breakdown the settler uses, so
    # the profile summary always matches the scorecard page.
    scored_race_ids = @race_picks.select { |rp| rp.race.has_results? }.map(&:race_id)
    @pick_summaries = {}
    if scored_race_ids.any?
      finishes = RaceResult.where(race_id: scored_race_ids).where.not(position_order: nil)
                           .pluck(:race_id, :driver_id, :position_order)
                           .group_by(&:first)
                           .transform_values { |rows| rows.to_h { |r| [r[1], r[2]] } }
      @race_picks.each do |rp|
        next unless finishes.key?(rp.race_id)
        @pick_summaries[rp.id] = Fantasy::ScoreRacePicks.breakdown(
          rp.placed_drivers,
          finishes[rp.race_id],
          scoring_limit: Fantasy::ScoreRacePicks.scoring_limit_for(rp.race)
        )
      end
    end

    @predictions = Prediction.where(user: @user)
                             .joins(race: :season)
                             .where(seasons: { year: @season.year })
                             .includes(race: [:circuit, :season])
                             .order("races.round DESC")

    # Driver cards earned this season — surfaced on the portfolio so users see
    # them next to the picks that earned them. Full collection lives at /cards.
    # We group by driver so each card "deck" shows the full per-driver picture
    # (combine pill needs the whole tier count, not just the recent slice).
    season_cards = DriverCard.where(user: @user)
                             .joins(:race)
                             .where(races: { season_id: @season.id })
                             .includes(:driver, race: [:circuit, :season])
                             .to_a
    @driver_cards_total       = season_cards.size
    @driver_cards_tier_counts = season_cards.group_by(&:tier).transform_values(&:count)
    # Group by driver, sort each driver's group by most-recent card desc, then
    # take the 4 drivers whose most recent card is newest.
    @driver_cards_decks = season_cards
      .group_by(&:driver_id)
      .values
      .sort_by { |grp| -grp.map(&:earned_at).max.to_i }
      .first(4)
  end

  # ═══════════════════════════════════════
  # Portfolio creation
  # ═══════════════════════════════════════

  def new
    existing = current_user.fantasy_portfolio_for(current_season)
    if existing
      redirect_to fantasy_overview_path(current_user.username)
      return
    end

    @season = current_season
    @starting_capital = compute_starting_capital
  end

  def create
    result = Fantasy::CreatePortfolio.new(user: current_user, season: current_season).call

    if result[:error]
      redirect_to new_fantasy_portfolio_path, alert: result[:error]
    else
      redirect_to fantasy_overview_path(current_user.username), notice: "Portfolio created! You have #{result[:portfolio].cash.round(0)} credits to spend."
    end
  end

  # ═══════════════════════════════════════
  # Leaderboards
  # ═══════════════════════════════════════

  def leaderboard
    @season = current_season
    @entries = Fantasy::Leaderboard.new(season: @season).call
    starting = Fantasy::CreatePortfolio::STARTING_CAPITAL
    roster_starts = @entries.each_with_object({}) { |e, h| h[e[:portfolio].id] = starting }
    @roster_deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, @entries.map { |e| e[:portfolio].id }, starting_values: roster_starts)
    user_ids = @entries.map { |e| e[:portfolio].user_id }
    @supports_by_user = ConstructorSupport.where(user_id: user_ids, season: @season, active: true)
                          .includes(:constructor).index_by(&:user_id)
  end

  def combined_leaderboard
    @season = current_season
    @entries = Fantasy::Leaderboard.new(season: @season).call

    starting = Fantasy::CreatePortfolio::STARTING_CAPITAL
    portfolio_ids = @entries.map { |e| e[:portfolio].id }
    starts = portfolio_ids.each_with_object({}) { |id, h| h[id] = starting }
    @deltas = last_race_deltas(FantasySnapshot, :fantasy_portfolio_id, portfolio_ids, starting_values: starts)

    user_ids = @entries.map { |e| e[:portfolio].user_id }
    @supports_by_user = ConstructorSupport.where(user_id: user_ids, season: @season, active: true)
                          .includes(:constructor).index_by(&:user_id)

    # Season shape per player, for the inline sparkline. A standings table says
    # who is ahead; it says nothing about who is climbing and who is sliding,
    # which is the more interesting half of a leaderboard.
    @sparklines = FantasySnapshot.where(fantasy_portfolio_id: portfolio_ids)
                    .joins(:race).order("races.date ASC")
                    .pluck(:fantasy_portfolio_id, :value)
                    .each_with_object(Hash.new { |h, k| h[k] = [] }) { |(pid, value), acc| acc[pid] << value.to_f }
    @sparklines.each_value { |vals| vals.unshift(starting.to_f) }

    # Gap to the leader, so mid-table rows read as a race rather than a list.
    @leader_value = @entries.first&.dig(:value)

    render "fantasy_portfolios/combined_leaderboard"
  end

  # ═══════════════════════════════════════
  # Profile visibility toggle
  # ═══════════════════════════════════════

  def toggle_public
    current_user.update!(public_profile: !current_user.public_profile?)
    status = current_user.public_profile? ? "public" : "private"
    redirect_back fallback_location: fantasy_overview_path(current_user.username),
                  notice: "Profile is now #{status}."
  end

  private
end
