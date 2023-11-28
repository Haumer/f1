class SeasonsController < ApplicationController
    def index
        @seasons = Season.sorted_by_year
    end

    def show
        @season = Season.find(params[:id])
        @next_season = @season.next_season
        @previous_season = @season.previous_season
        @sorted_races = @season.races.order(round: :asc)
        @driver_driver_standings = @season.drivers.map do |driver|
            DriverStanding.where(driver: driver, race_id: @sorted_races.pluck(:id))
        end
        @driver_driver_standings = @driver_driver_standings.reject(&:blank?).sort_by do |driver_standing|
            -driver_standing.last.points
        end
    end
end
