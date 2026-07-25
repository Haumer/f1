class HeadToHeadController < ApplicationController
  SESSION_COOKIE = :h2h_session_token
  TOKEN_ATTR = "h2h_session_token"

  def show
    year = requested_year
    @year = year

    session_record = current_unfinished_session_for(year) || start_new(year)
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
    old = current_unfinished_session_for(year)
    old&.update!(finished_at: Time.current) if old && !old.finished?
    session_record = start_new(year)
    session.delete(:h2h_champion_side)
    redirect_to head_to_head_path(year: (year == current_season.year.to_i ? nil : year))
  end

  def pick
    # Cookie tokens are per-user, not per-game — always take the most recent
    # unfinished session for this cookie so a stale finished game doesn't
    # capture picks from a fresh round.
    session_record = current_unfinished_session_for(requested_year) or
      return redirect_to(head_to_head_path)

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
    # Pull the most recent session for this cookie — the one we just finished.
    # Not the URL param, which used to carry the cookie token (not unique per
    # game) and would resolve to the oldest matching session.
    @session_record = latest_session_for(requested_year)
    unless @session_record
      redirect_to head_to_head_path and return
    end
    @year = @session_record.year
    @champion = @session_record.champion_driver
    @top_ranked = @session_record.top_ranked(12)
    @total_sessions = DriverPreferenceSession.where(year: @year).where.not(finished_at: nil).count
  end

  def results
    @year = requested_year
    matches = DriverPreferenceMatch.where(year: @year)
    grouped = matches.group(:winner_driver_id).count
    losses  = matches.group(:loser_driver_id).count

    driver_ids = (grouped.keys + losses.keys).uniq
    drivers = Driver.where(id: driver_ids).index_by(&:id)

    @rows = driver_ids.map do |id|
      wins = grouped[id] || 0
      loss = losses[id]  || 0
      total = wins + loss
      pct = total.zero? ? 0.0 : (wins.to_f / total)
      {
        driver: drivers[id],
        wins: wins,
        losses: loss,
        total: total,
        pct: pct,
      }
    end.select { |r| r[:driver] }.sort_by { |r| [-r[:pct], -r[:total]] }

    @total_sessions = DriverPreferenceSession.where(year: @year).where.not(finished_at: nil).count
    @total_matches  = matches.count
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

  def current_unfinished_session_for(year)
    DriverPreferenceSession
      .where(session_token: session_token, year: year, finished_at: nil)
      .order(started_at: :desc)
      .first
      .tap { |s| s.update!(user_id: current_user.id) if s && current_user && s.user_id.nil? }
  end

  def latest_session_for(year)
    DriverPreferenceSession
      .where(session_token: session_token, year: year)
      .order(started_at: :desc)
      .first
      .tap { |s| s.update!(user_id: current_user.id) if s && current_user && s.user_id.nil? }
  end

  def start_new(year)
    DriverPreferenceSession.create!(
      user: current_user,
      session_token: session_token,
      year: year,
      started_at: Time.current,
      rounds_target: 12,
    )
  end

  def finalize(session_record)
    session_record.update!(finished_at: Time.current) if session_record.finished_at.nil?
  end
end
