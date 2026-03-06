class PagesController < ApplicationController
  include StandingsData

  def home
    set_current_champion_accent

    # Show the current year's season if it has standings OR we're within 1 month of its first race.
    # Otherwise fall back to latest season with data.
    effective_year = Setting.effective_today.year
    current = Season.find_by(year: effective_year.to_s)
    first_race_date = current&.races&.order(:date)&.first&.date
    today = Setting.effective_today
    current_season_active = current&.latest_driver_standings&.any? ||
                            (first_race_date && first_race_date - 1.month <= today)

    @season = if current_season_active
                current
              else
                Season.sorted_by_year.joins(races: :driver_standings).distinct.first
              end

    if @season
      @today = Setting.effective_today

      # If current season has no standings yet, use the previous season for standings/chart/movers
      @standings_season = if @season.latest_driver_standings&.any?
                            @season
                          else
                            Season.sorted_by_year.where.not(id: @season.id)
                                  .joins(races: :driver_standings).distinct.first
                          end

      @standings_extras = @standings_season ? build_standings_extras(@standings_season) : {}

      if @standings_season && @standings_season != @season
        top3_standings = @standings_season.latest_driver_standings&.first(3)
        if top3_standings&.any?
          sd_index = SeasonDriver.where(season: @standings_season).includes(:constructor).index_by(&:driver_id)
          @recap_constructors = top3_standings.each_with_object({}) do |ds, hash|
            hash[ds.driver_id] = sd_index[ds.driver_id]&.constructor
          end
        end
      end

      # Last Race Result widget (from standings season)
      @latest_race = @standings_season&.latest_race
      @podium_results = @latest_race&.race_results&.where(position_order: 1..3)
                                    &.order(position_order: :asc)
                                    &.includes(driver: :countries, constructor: [])

      # Elo Movers (from standings season)
      if @standings_extras.present?
        sorted_extras = @standings_extras.select { |_id, e| e[:elo_diff].present? }
        @elo_gainers = sorted_extras.sort_by { |_id, e| -(e[:elo_diff] || 0) }.first(5)
        @elo_losers  = sorted_extras.sort_by { |_id, e| e[:elo_diff] || 0 }.first(5)
        mover_ids = (@elo_gainers + @elo_losers).map(&:first)
        @drivers_by_id = Driver.where(id: mover_ids).includes(:countries, season_drivers: :constructor).index_by(&:id)
      end

      # Quick Stats
      @races_completed = if Setting.simulated_date
                           @season.races.joins(:race_results).where("races.date <= ?", @today).distinct.count
                         else
                           @season.races.joins(:race_results).distinct.count
                         end
      @total_races = @season.races.count
      @leader = @standings_season&.latest_driver_standings&.first
      elo_col = Setting.elo_column(:elo)
      @highest_elo_driver = Driver.active.order(elo_col => :desc).first
      @most_wins = @standings_season&.latest_driver_standings&.max_by { |ds| ds.wins || 0 }

      # Current season driver grid
      elo_col_grid = Setting.elo_column(:elo)
      lineup_season = SeasonDriver.where(season: @season).exists? ? @season : @season.previous_season
      if lineup_season
        @season_drivers = SeasonDriver.where(season: lineup_season, standin: [false, nil])
                            .includes(driver: :countries, constructor: [])
                            .sort_by { |sd| -sd.id }
                            .uniq(&:driver_id)
                            .sort_by { |sd| -(sd.driver.send(elo_col_grid) || 0) }
      end

      # Season standings lookup for grid table
      latest_standings = @season.latest_driver_standings
      @grid_standings = latest_standings.index_by(&:driver_id)

      # Previous race standings for position change
      if @season.latest_race
        prev_race = @season.races.where("round < ?", @season.latest_race.round).order(round: :desc).first
        @grid_prev_standings = prev_race ? DriverStanding.where(race: prev_race).index_by(&:driver_id) : {}
      else
        @grid_prev_standings = {}
      end

      # Find contextual race and next race
      @next_race = @season.next_race
      if @next_race.nil?
        @next_race = Race.where("date >= ?", @today).order(:date).includes(:circuit).first
      end

      # Season complete check (for standings season, not current season)
      if @standings_season
        if Setting.simulated_date
          @season_complete = @today > (@standings_season.last_race&.date || Date.new(2099))
        else
          @season_complete = @standings_season.last_race&.race_results&.any?
        end
      end

      # Champion data (when standings season is complete)
      if @season_complete && @standings_season
        champion_standing = DriverStanding.find_by(
          race: @standings_season.last_race,
          position: 1,
          season_end: true
        )
        if champion_standing
          @champion = champion_standing.driver
          @champion_standing = champion_standing
          @champion_constructor = @champion.constructor_for(@standings_season)
        end
      end

      # Constructor top 3 for previous season recap
      # Uses race_results.constructor_id for correct team attribution (handles mid-season swaps),
      # then scales each driver's share up to their driver_standing total (which includes sprint points)
      if @standings_season && @standings_season != @season
        last_race = @standings_season.races.order(:round).last
        if last_race
          race_ids = @standings_season.races.pluck(:id)
          # Points per driver per constructor from race_results (correct team attribution)
          rr_points = RaceResult.where(race_id: race_ids).where.not(constructor_id: nil)
                        .group(:driver_id, :constructor_id).sum(:points)
          # Driver standing totals (includes sprint points)
          ds_totals = DriverStanding.where(race: last_race).pluck(:driver_id, :points, :wins).to_h { |did, pts, w| [did, { points: pts || 0, wins: w || 0 }] }
          # Distribute each driver's standing points to constructors proportionally
          constructor_points = Hash.new(0.0)
          constructor_wins = Hash.new(0)
          rr_points.each do |(driver_id, constructor_id), rr_pts|
            ds = ds_totals[driver_id]
            next unless ds
            driver_rr_total = rr_points.select { |(did, _), _| did == driver_id }.values.sum
            if driver_rr_total > 0
              ratio = rr_pts.to_f / driver_rr_total
              constructor_points[constructor_id] += ds[:points] * ratio
              constructor_wins[constructor_id] += (ds[:wins] * ratio).round
            end
          end
          # Wins from race_results (more accurate than proportional split)
          constructor_wins = RaceResult.where(race_id: race_ids, position_order: 1)
                               .where.not(constructor_id: nil)
                               .group(:constructor_id).count
          top_ids = constructor_points.sort_by { |_, pts| -pts }.first(3).map(&:first)
          constructors = Constructor.where(id: top_ids).index_by(&:id)
          @constructor_top3 = top_ids.map do |cid|
            { constructor: constructors[cid], points: constructor_points[cid].round, wins: constructor_wins[cid] || 0 }
          end
        end
      end

      # Phase detection
      @contextual_race = find_contextual_race
      @homepage_phase = determine_homepage_phase
      prepare_phase_data

      # Fantasy portfolio for logged-in users
      if current_user
        @fantasy_portfolio = current_user.fantasy_portfolio_for(@season)
        @fantasy_stock_portfolio = current_user.fantasy_stock_portfolio_for(@season)
        if @fantasy_portfolio
          @fantasy_support = ConstructorSupport.current_for(current_user, @season)
          @fantasy_rank = @fantasy_portfolio.snapshots.order(created_at: :desc).first&.rank
        end
      end
    end
  end

  def about
    set_current_champion_accent
  end

  def fantasy_guide
    set_current_champion_accent
  end

  def elo
    peak_col = Setting.elo_column(:peak_elo)
    thresholds = Setting.use_elo_v2? ? [2600, 2450, 2300, 2100] : [1500, 1400, 1300, 1200]
    @tier_counts = {
      elite: Driver.where("#{peak_col} >= ?", thresholds[0]).count,
      world_class: Driver.where("#{peak_col} >= ? AND #{peak_col} < ?", thresholds[1], thresholds[0]).count,
      strong: Driver.where("#{peak_col} >= ? AND #{peak_col} < ?", thresholds[2], thresholds[1]).count,
      average: Driver.where("#{peak_col} >= ? AND #{peak_col} < ?", thresholds[3], thresholds[2]).count,
      developing: Driver.where("#{peak_col} < ?", thresholds[3]).where.not(peak_col => nil).count
    }
    @total_drivers = Driver.where.not(peak_col => nil).count
    @total_races = Race.joins(:race_results).distinct.count

    # Interactive race example
    @recent_races = Race.joins(:race_results).distinct
                        .includes(:circuit, :season)
                        .order(date: :desc).limit(10)

    @example_race = if params[:race_id].present?
                      Race.find_by(id: params[:race_id])
                    else
                      @recent_races.first
                    end

    if @example_race
      elo_diff_col = Setting.use_elo_v2? ? :elo_diff_v2 : :elo_diff
      @example_results = @example_race.race_results
                           .includes(driver: :countries, constructor: [])
                           .order(:position_order)
      old_elo_col = Setting.elo_column(:old_elo)
      elo_values = @example_results.filter_map { |rr| rr.send(old_elo_col) }
      @avg_field_elo = elo_values.any? ? (elo_values.sum / elo_values.size).round : nil
      @example_biggest_gainer = @example_results.max_by { |rr| rr.display_elo_diff }
      @example_biggest_loser = @example_results.min_by { |rr| rr.display_elo_diff }
    end
  end

  private

  def find_contextual_race
    # Find a race whose weekend window (FP1 through race+2) covers today
    candidate = Race.where("date - 2 <= ? AND date + 2 >= ?", @today, @today)
                    .order(:date)
                    .includes(:circuit, :race_results)
                    .first

    candidate || @next_race
  end

  def determine_homepage_phase
    return :default unless @contextual_race

    race = @contextual_race
    fp1_date = race.fp1_date
    race_date = race.date

    # Post-race: race has results and within 2 days after
    if race.has_results? && @today >= race_date && @today <= race_date + 2.days
      return :post_race
    end

    # Also check latest_race for post-race window
    if @latest_race&.has_results? && @today >= @latest_race.date && @today <= @latest_race.date + 2.days
      @contextual_race = @latest_race
      return :post_race
    end

    # Race day
    return :race_day if @today == race_date

    # Race weekend (FP1 day through day before race)
    return :race_weekend if @today >= fp1_date && @today < race_date

    # Pre-race lead-up (7 days before FP1)
    return :pre_race if @today >= (fp1_date - 7.days) && @today < fp1_date

    # Season start (current season exists but has no results yet)
    first_race = @season.first_race
    if first_race && !@season.latest_driver_standings&.any? && first_race.date > @today
      return :season_start
    end

    # Season complete (only when no active race context)
    return :season_complete if @season_complete && @champion

    :default
  end

  def prepare_phase_data
    race = @contextual_race
    return unless race

    # Find next upcoming session for countdown timer
    @next_session = race.session_schedule.find { |s| s[:starts_at].present? && s[:starts_at] > Time.current }

    case @homepage_phase
    when :race_weekend, :race_day
      @weekend_race = race
      @session_schedule = build_session_schedule(race)
      @circuit_kings = DriverBadge.circuit_kings_for(race.circuit_id)

    when :pre_race
      @countdown_race = race
      @days_until_fp1 = (race.fp1_date - @today).to_i
      @circuit_kings = DriverBadge.circuit_kings_for(race.circuit_id)

    when :season_start
      @first_race = @season.first_race

      elo_col = Setting.elo_column(:elo)
      @power_rankings = Driver.active
        .where.not(elo_col => nil)
        .order(elo_col => :desc)
        .limit(10)
        .includes(:countries, season_drivers: :constructor)

      # Try current season constructors, fall back to previous season's
      season_for_constructors = @season
      unless SeasonDriver.where(season: @season).exists?
        season_for_constructors = @season.previous_season
      end
      constructor_elo_col = Setting.elo_column(:elo)
      @constructor_rankings = if season_for_constructors
        Constructor.where.not(constructor_elo_col => nil)
          .joins(:season_drivers)
          .where(season_drivers: { season_id: season_for_constructors.id })
          .distinct
          .order(constructor_elo_col => :desc)
      else
        Constructor.none
      end

      @active_driver_count = Driver.active.count
      @total_races_tracked = Race.joins(:race_results).distinct.count

      prev_season = @season.previous_season
      if prev_season
        champion_standing = DriverStanding.find_by(
          race: prev_season.last_race, position: 1, season_end: true
        )
        @prev_champion = champion_standing&.driver
        @prev_champion_standing = champion_standing
        @prev_champion_constructor = @prev_champion&.constructor_for(prev_season)
        @prev_season = prev_season
      end

    when :post_race
      @post_race = race
      @circuit_kings = DriverBadge.circuit_kings_for(race.circuit_id)
      @podium_results_post = race.race_results
        .where(position_order: 1..3)
        .order(position_order: :asc)
        .includes(driver: :countries, constructor: [])

      @race_elo_changes = race.race_results
        .includes(driver: :countries, constructor: [])
        .sort_by { |rr| -(rr.display_elo_diff.abs) }
        .first(5)
    end
  end

  def build_session_schedule(race)
    now = Time.current
    sessions = race.session_schedule.map.with_index do |session, idx|
      # Use starts_at for time-aware status; fall back to date comparison
      next_session_start = race.session_schedule[idx + 1]&.dig(:starts_at)
      session_start = session[:starts_at]

      status = if session_start && next_session_start
                 # Session is done if the next session has already started
                 if next_session_start <= now
                   :done
                 elsif session_start <= now
                   :today # currently live or just finished (before next starts)
                 else
                   :upcoming
                 end
               elsif session_start
                 # Last session (Race): done if 2h past start, live if started
                 if session_start + 2.hours <= now
                   :done
                 elsif session_start <= now
                   :today
                 else
                   :upcoming
                 end
               else
                 # No timestamps, fall back to date
                 if session[:date] < @today
                   :done
                 elsif session[:date] == @today
                   :today
                 else
                   :upcoming
                 end
               end
      session.merge(status: status)
    end

    # Compute connector fill between each pair of sessions.
    # connector_before_fill on session[i] = fill % of the line between session[i-1] and session[i].
    sessions.each_with_index do |session, i|
      prev = i > 0 ? sessions[i - 1] : nil
      session[:connector_before_fill] = if prev.nil?
                                           0
                                         elsif prev[:status] == :done && session[:status] == :done
                                           100
                                         elsif prev[:status] == :done && session[:status] == :today
                                           100
                                         elsif prev[:status] == :done && session[:status] == :upcoming
                                           100
                                         elsif prev[:status] == :today && session[:status] == :upcoming
                                           connector_time_progress(prev, session)
                                         elsif prev[:status] == :today && session[:status] == :today
                                           100
                                         else
                                           0
                                         end
    end

    sessions
  end

  def connector_time_progress(current, upcoming)
    return 50 unless current[:starts_at] && upcoming[:starts_at]

    now = Time.current
    total = (upcoming[:starts_at] - current[:starts_at]).to_f
    elapsed = (now - current[:starts_at]).to_f
    return 0 if total <= 0

    pct = ((elapsed / total) * 100).clamp(0, 100).round
    [pct, 10].max # Show at least 10% so it's visible
  end
end
