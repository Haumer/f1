class DriversController < ApplicationController
    def show
        @driver = Driver.find(params[:id])
        @season_1st_place_finishes = @driver.driver_standings.where(position: 1, season_end: true).sort_by(&:race)
        @season_2nd_place_finishes = @driver.driver_standings.where(position: 2, season_end: true).sort_by(&:race)
        @season_3rd_place_finishes = @driver.driver_standings.where(position: 3, season_end: true).sort_by(&:race)
    end
    
    def index
        if params[:search].present? && params[:search][:query].length > 1
            @drivers = Driver.name_and_constructor_search(params[:search][:query])
        else
            @drivers = Driver.all.by_surname
        end
        # render(partial: 'drivers', locals: { drivers: @drivers })
    end

    def peak_elo
        # @drivers = Driver.where(first_race_date: Date.new(1980,1,1)..Date.today).order(peak_elo: :desc).first(10)
        @race_results = Driver.elite.map { |driver| driver.peak_elo_race_result }.sort_by { |race_result| -race_result.new_elo }
    end

    def current_active_elo
        @drivers = Driver.active.order(elo: :desc)
    end

    def compare
    end
end
