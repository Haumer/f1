class PagesController < ApplicationController
  include StandingsData

  def home
    SeasonSync.sync_if_stale!

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

      # Phase detection
      @contextual_race = find_contextual_race
      @homepage_phase = determine_homepage_phase
      prepare_phase_data

      # Fantasy portfolio for logged-in users
      if current_user
        @fantasy_portfolio = current_user.fantasy_portfolio_for(@season)
      end
    end
  end

  def about
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
      @circuit_kings = DriverBadge.where("key = ?", "circuit_king_#{race.circuit_id}")
                                  .includes(:driver).order(Arel.sql("CASE tier WHEN 'gold' THEN 0 WHEN 'silver' THEN 1 WHEN 'bronze' THEN 2 ELSE 3 END"))

    when :pre_race
      @countdown_race = race
      @days_until_fp1 = (race.fp1_date - @today).to_i
      @circuit_kings = DriverBadge.where("key = ?", "circuit_king_#{race.circuit_id}")
                                  .includes(:driver).order(Arel.sql("CASE tier WHEN 'gold' THEN 0 WHEN 'silver' THEN 1 WHEN 'bronze' THEN 2 ELSE 3 END"))

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
      @circuit_kings = DriverBadge.where("key = ?", "circuit_king_#{race.circuit_id}")
                                  .includes(:driver).order(Arel.sql("CASE tier WHEN 'gold' THEN 0 WHEN 'silver' THEN 1 WHEN 'bronze' THEN 2 ELSE 3 END"))
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
    sessions = race.session_schedule.map do |session|
      status = if session[:date] < @today
                 :done
               elsif session[:date] == @today
                 :today
               else
                 :upcoming
               end
      session.merge(status: status)
    end

    # Compute connector fill percentages for progress bar effect.
    # Each session gets :connector_before_fill and :connector_after_fill (0–100).
    sessions.each_with_index do |session, i|
      prev_session = i > 0 ? sessions[i - 1] : nil
      next_session = i < sessions.length - 1 ? sessions[i + 1] : nil

      # Connector before this dot
      session[:connector_before_fill] = if prev_session.nil?
                                           0
                                         elsif prev_session[:status] == :done && session[:status] != :upcoming
                                           100
                                         elsif prev_session[:status] == :today && session[:status] == :upcoming
                                           0
                                         else
                                           0
                                         end

      # Connector after this dot
      session[:connector_after_fill] = if next_session.nil?
                                          0
                                        elsif session[:status] == :done && next_session[:status] != :upcoming
                                          100
                                        elsif session[:status] == :done && next_session[:status] == :upcoming
                                          # Done → upcoming: fill the after half fully (progress is past this dot)
                                          100
                                        elsif session[:status] == :today && next_session[:status] == :upcoming
                                          # Today → upcoming: time-based progress within this half
                                          connector_time_progress(session, next_session)
                                        elsif session[:status] == :today && next_session[:status] == :today
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
