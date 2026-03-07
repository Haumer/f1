module HomepageData
  extend ActiveSupport::Concern

  SESSION_DURATIONS = {
    fp1: 1.hour, fp2: 1.hour, fp3: 1.hour,
    quali: 1.hour, sprint_quali: 1.hour,
    sprint: 1.hour, race: 2.hours + 30.minutes
  }.freeze

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
      session_start = session[:starts_at]
      duration = SESSION_DURATIONS[session[:key]] || 1.hour

      status = if session_start
                 if session_start + duration <= now
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
                                           connector_gap_progress(prev, session)
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

  # Progress in the gap between a finished session and the next upcoming one.
  # E.g. FP1 ended at 14:00, FP2 starts at 18:00 — show how far through the gap we are.
  def connector_gap_progress(prev_session, next_session)
    return 100 unless prev_session[:starts_at] && next_session[:starts_at]

    now = Time.current
    prev_duration = SESSION_DURATIONS[prev_session[:key]] || 1.hour
    gap_start = prev_session[:starts_at] + prev_duration
    gap_end = next_session[:starts_at]
    total = (gap_end - gap_start).to_f
    return 100 if total <= 0

    elapsed = (now - gap_start).to_f
    pct = ((elapsed / total) * 100).clamp(0, 100).round
    [pct, 10].max
  end
end
