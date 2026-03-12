class RacePicksController < ApplicationController
  before_action :authenticate_user!, only: [:update]
  before_action :set_race
  before_action :set_race_pick, only: [:update]

  def edit
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
      redirect_to fantasy_overview_path(current_user.username), notice: "Your picks for #{@race.circuit.name} have been saved!"
    else
      load_drivers
      render :edit
    end
  end

  private

  def set_race
    @season = Season.sorted_by_year.first
    @race = @season&.next_race
    unless @race
      redirect_to root_path, alert: "No upcoming race to make picks for."
    end
  end

  def set_race_pick
    @race_pick = RacePick.find_or_initialize_by(user: current_user, race: @race)
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
