class HeadToHeadController < ApplicationController
  SESSION_COOKIE = :h2h_session_token

  def show
    year = requested_year
    @year = year
    anchor_race = current_anchor_race(year)

    session_record = session_for_race(year, anchor_race) || start_new(year, anchor_race)
    @session_record = session_record

    if session_record.finished?
      redirect_to finish_head_to_head_path and return
    end

    pair = HeadToHead::PairPicker.new(session_record).next_pair
    if pair.nil?
      finalize(session_record)
      redirect_to finish_head_to_head_path and return
    end
    @pair = pair
    @champion_side = %w[left right].include?(session[:h2h_champion_side]) ? session[:h2h_champion_side] : "left"
  end

  def start
    year = requested_year
    anchor_race = current_anchor_race(year)
    existing = session_for_race(year, anchor_race)

    # Per-race gate: one session per cookie per race. If a session already
    # exists for the current anchor race, jump into it (or its finish page)
    # rather than creating a duplicate.
    if existing
      redirect_to(existing.finished? ? finish_head_to_head_path : head_to_head_path(year: url_year_param(year)))
      return
    end

    session.delete(:h2h_champion_side)
    start_new(year, anchor_race)
    redirect_to head_to_head_path(year: url_year_param(year))
  end

  def pick
    # Race-anchored session: picks land on the session for the current race.
    year = requested_year
    session_record = session_for_race(year, current_anchor_race(year)) or
      return redirect_to(head_to_head_path)
    return redirect_to(finish_head_to_head_path) if session_record.finished?

    winner_id = params[:winner_driver_id].to_i
    loser_id  = params[:loser_driver_id].to_i
    round     = session_record.rounds_played
    tier      = HeadToHead::PairPicker.new(session_record).tier_for_round(round)

    # Guard against double-submits / stale rounds.
    if session_record.matches.exists?(round_index: round)
      return redirect_to head_to_head_path(year: url_year_param(session_record.year))
    end

    ActiveRecord::Base.transaction do
      session_record.matches.create!(
        winner_driver_id: winner_id,
        loser_driver_id:  loser_id,
        year:  session_record.year,
        round_index: round,
        tier:  tier,
        created_at: Time.current,
      )
      session_record.update!(
        champion_driver_id: winner_id,
        rounds_played: round + 1,
      )
    end

    picked_side = params[:picked_side]
    session[:h2h_champion_side] = picked_side if %w[left right].include?(picked_side)

    if session_record.reload.finished?
      finalize(session_record)
      redirect_to finish_head_to_head_path
    else
      redirect_to head_to_head_path(year: url_year_param(session_record.year))
    end
  end

  def finish
    @session_record = latest_session_for(requested_year)
    unless @session_record
      redirect_to head_to_head_path and return
    end
    @year = @session_record.year
    @champion = @session_record.champion_driver
    @top_ranked = @session_record.top_ranked(12)
    @total_sessions = DriverPreferenceSession.finished.where(year: @year).count

    # Play-again gate: unlocked once the current anchor race is different from
    # the race this session was anchored to (i.e., the race has completed and
    # a new round is up).
    anchor = current_anchor_race(@year)
    @can_play_again = @session_record.race_id.nil? || (anchor && anchor.id != @session_record.race_id)
    @next_unlock_race = @can_play_again ? nil : @session_record.race
  end

  def results
    @year = requested_year
    @rows = HeadToHead::CrowdRanker.call(@year)
    @podium_min = HeadToHead::CrowdRanker::PODIUM_MIN_TOTAL
    @total_sessions = DriverPreferenceSession.finished.where(year: @year).count
    @total_matches  = DriverPreferenceMatch.where(year: @year).count
  end

  private

  def requested_year
    y = params[:year].to_i
    y.zero? ? current_season.year.to_i : y
  end

  def url_year_param(year)
    year == current_season.year.to_i ? nil : year
  end

  def session_token
    existing = cookies.signed[SESSION_COOKIE]
    return existing if existing.present?
    new_token = SecureRandom.urlsafe_base64(24)
    cookies.signed[SESSION_COOKIE] = {
      value: new_token, expires: 1.year.from_now, httponly: true, same_site: :lax,
    }
    new_token
  end

  def current_anchor_race(year)
    season = Season.find_by(year: year.to_s)
    return nil unless season
    season.next_race || season.last_race
  end

  def session_for_race(year, race)
    scope = DriverPreferenceSession.where(session_token: session_token, year: year)
    scope = scope.where(race_id: race.id) if race
    link_to_current_user(scope.order(started_at: :desc).first)
  end

  def latest_session_for(year)
    session = DriverPreferenceSession
      .where(session_token: session_token, year: year)
      .order(started_at: :desc)
      .first
    link_to_current_user(session)
  end

  # Once a guest signs in, retro-link their in-flight/finished sessions so the
  # bonus flow and future analytics see the same user.
  def link_to_current_user(session)
    return nil unless session
    session.update!(user_id: current_user.id) if current_user && session.user_id.nil?
    session
  end

  def start_new(year, race = nil)
    DriverPreferenceSession.create!(
      user: current_user,
      session_token: session_token,
      year: year,
      race: race,
      started_at: Time.current,
      rounds_target: 12,
    )
  end

  def finalize(session_record)
    session_record.update!(finished_at: Time.current) if session_record.finished_at.nil?
    HeadToHead::AwardCompletionBonus.new(session_record).call
  end
end
