class PredictionsController < ApplicationController
  def show
    @race = Race.includes(:circuit, :season).find(params[:id])
    @user = User.find_by!(username: params[:username])
    @prediction = Prediction.find_by!(race: @race, user: @user)

    set_race_winner_accent(@race)

    # Pre-load drivers for the predicted result
    driver_ids = @prediction.predicted_results.map { |r| r["driver_id"] }
    @drivers_by_id = Driver.where(id: driver_ids).includes(:countries).index_by(&:id)

    # Pre-load constructors for the season
    season = @race.season
    season_drivers = SeasonDriver.where(season: season, driver_id: driver_ids).includes(:constructor)
    @constructor_by_driver = season_drivers.each_with_object({}) { |sd, h| h[sd.driver_id] = sd.constructor }

    # Elo changes (pre-computed)
    @elo_changes = @prediction.elo_changes || {}

    # User's team support (for colored username + logo)
    @support = ConstructorSupport.current_for(@user, @race.season)
  end
end
