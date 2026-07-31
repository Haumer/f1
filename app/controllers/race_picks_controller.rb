class RacePicksController < ApplicationController
  before_action :authenticate_user!, only: [:update]
  before_action :set_race, only: [:edit, :update, :stash]
  before_action :set_race_pick, only: [:update]

  def edit
    # Picks lock at race start — don't render an editable form that can't be saved.
    if current_user && !@race.picks_open?
      redirect_to fantasy_overview_path(current_user.username),
                  notice: "Picks are locked for #{@race.circuit.name} — the race has started."
      return
    end

    @race_pick = current_user ? RacePick.find_or_initialize_by(user: current_user, race: @race) : RacePick.new(race: @race)
    load_drivers
  end

  # Guest user: stash picks in session, redirect to signup
  def stash
    session[:pending_picks] = params[:picks]
    session[:pending_picks_race_id] = @race.id
    redirect_to new_user_registration_path, notice: "Create an account to save your picks!"
  end

  def update
    if @race_pick.locked?
      redirect_to fantasy_overview_path(current_user.username), alert: "Picks are locked for this race."
      return
    end

    raw_picks = params[:picks].present? ? JSON.parse(params[:picks]) : []
    @race_pick.picks = raw_picks
    @race_pick.locked_at = @race.starts_at

    if @race_pick.save
      redirect_to race_pick_compare_path(username: current_user.username, race_id: @race.id),
                  notice: "Your picks for #{@race.circuit.name} are locked in!"
    else
      load_drivers
      render :edit
    end
  end

  # "How you compare" — post-submit view showing user's picks alongside crowd stats.
  # Only meaningful before the race runs; after results exist, punt to the scorecard.
  def compare
    @user = User.find_by!(username: params[:username])
    @is_owner = current_user&.id == @user.id
    unless @is_owner || @user.public_profile?
      redirect_to combined_leaderboard_path, alert: "This profile is private."
      return
    end

    @race = Race.find_by(id: params[:race_id])
    @race_pick = @race && RacePick.find_by(user: @user, race: @race)

    if @race.nil? || @race_pick&.picks.blank?
      redirect_to fantasy_overview_path(@user.username), alert: "No picks found for that race." and return
    end

    if @race.race_results.exists?
      redirect_to race_pick_results_path(username: @user.username, race_id: @race.id) and return
    end

    @comparison = build_pick_comparison(@race, @race_pick)
  end

  # Scorecard: how a user's ranking for a completed race actually scored.
  # Viewable by the owner, or by anyone if the profile is public (mirrors the
  # fantasy overview's visibility rule).
  def results
    @user = User.find_by!(username: params[:username])
    @is_owner = current_user&.id == @user.id
    unless @is_owner || @user.public_profile?
      redirect_to combined_leaderboard_path, alert: "This profile is private."
      return
    end

    @race = Race.find_by(id: params[:race_id])
    @race_pick = @race && RacePick.find_by(user: @user, race: @race)

    if @race.nil? || @race_pick&.picks.blank? || !@race.race_results.exists?
      redirect_to fantasy_overview_path(@user.username),
                  alert: "No scored picks found for that race."
      return
    end

    placed = @race_pick.placed_drivers
    finish = RaceResult.where(race: @race).where.not(position_order: nil)
                       .pluck(:driver_id, :position_order).to_h
    @scoring_limit = Fantasy::ScoreRacePicks.scoring_limit_for(@race)
    @breakdown = Fantasy::ScoreRacePicks.breakdown(placed, finish, scoring_limit: @scoring_limit)

    driver_ids = placed.map { |p| p["driver_id"] }
    @drivers_by_id = Driver.where(id: driver_ids).index_by(&:id)
    @constructors_by_driver = SeasonDriver.where(season_id: @race.season_id, driver_id: driver_ids)
                                          .includes(:constructor)
                                          .index_by(&:driver_id)
                                          .transform_values(&:constructor)
  end

  private

  def set_race
    @season = current_season
    @race = @season&.next_race
    unless @race
      redirect_to root_path, alert: "No upcoming race to make picks for."
    end
  end

  def set_race_pick
    @race_pick = RacePick.find_or_initialize_by(user: current_user, race: @race)
  end

  # Returns a hash with:
  #   total_picks:      total unique users who submitted picks for this race
  #   rows:             per-position rows the user picked, each with { position, driver, agreement_pct, crowd_top: {driver, pct} }
  #   crowd_p1_top:     [{driver:, pct:}, ...] — top 3 crowd P1 picks (independent of user)
  #   contrarian_count: how many of the user's picks differ from the crowd's mode
  def build_pick_comparison(race, race_pick)
    all_picks = RacePick.where(race_id: race.id).pluck(:picks)
    total = all_picks.size

    # crowd[position][driver_id] = count
    crowd = Hash.new { |h, k| h[k] = Hash.new(0) }
    all_picks.each do |arr|
      (arr || []).each do |p|
        pos = p["position"]
        did = p["driver_id"]
        next unless pos && did

        crowd[pos][did] += 1
      end
    end

    user_rows = race_pick.placed_drivers
    driver_ids = (user_rows.map { |r| r["driver_id"] } + crowd.values.flat_map(&:keys)).compact.uniq
    drivers_by_id = Driver.where(id: driver_ids).index_by(&:id)

    rows = user_rows.map do |row|
      pos = row["position"]
      did = row["driver_id"]
      driver = drivers_by_id[did]
      picks_at_pos = crowd[pos]
      total_at_pos = picks_at_pos.values.sum
      my_matches = picks_at_pos[did].to_i
      top_did, top_count = picks_at_pos.max_by { |_, c| c } || [nil, 0]
      top_driver = drivers_by_id[top_did]

      {
        position: pos,
        driver: driver,
        agreement_pct: total_at_pos > 0 ? (my_matches.to_f / total_at_pos * 100).round : 0,
        contrarian: top_did && top_did != did,
        crowd_top: top_driver ? {
          driver: top_driver,
          pct: total_at_pos > 0 ? (top_count.to_f / total_at_pos * 100).round : 0
        } : nil
      }
    end

    crowd_p1 = crowd[1]
    p1_total = crowd_p1.values.sum
    crowd_p1_top = crowd_p1.sort_by { |_, c| -c }.first(3).map do |did, c|
      { driver: drivers_by_id[did], pct: p1_total > 0 ? (c.to_f / p1_total * 100).round : 0 }
    end.compact

    {
      total_picks: total,
      rows: rows,
      crowd_p1_top: crowd_p1_top,
      contrarian_count: rows.count { |r| r[:contrarian] }
    }
  end

  def load_drivers
    lineup_season = @season.lineup_season || @season
    season_driver_records = SeasonDriver.where(season: lineup_season, standin: [false, nil])
                              .includes(driver: :countries, constructor: [])
                              .sort_by { |sd| -sd.id }
                              .uniq(&:driver_id)

    @drivers = season_driver_records.map(&:driver)
    @constructors_by_driver = season_driver_records.each_with_object({}) { |sd, h| h[sd.driver_id] = sd.constructor }

    # True last 5 results per driver (across seasons)
    driver_ids = @drivers.map(&:id)
    recent_race_ids = Race.where("date < ?", @race.date)
                          .where(id: RaceResult.select(:race_id))
                          .order(date: :desc)
                          .limit(10)
                          .pluck(:id)

    @recent_results = RaceResult.where(driver_id: driver_ids, race_id: recent_race_ids)
                                .includes(race: :season, status: [])
                                .order("races.date DESC")
                                .group_by(&:driver_id)
                                .transform_values { |rrs| rrs.first(5) }

    # Default sort: by last result (form)
    @drivers = @drivers.sort_by { |d| @recent_results[d.id]&.first&.position_order || 99 }
  end
end
