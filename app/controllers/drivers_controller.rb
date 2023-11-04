class DriversController < ApplicationController
    def show
        @driver = Driver.find(params[:id])
    end
    
    def index
        if params[:search].present?
            begin
                search_date_start = Date.parse(params[:search][:first_race_date])
            rescue => exception
                search_date_start = Date.new(1930,1,1)
            end
            active_drivers = params[:search][:active] == 'true' ? true : [true, false]

            races = Race.where(date: search_date_start..Date.today)
            driver_ids = races.map(&:drivers).flatten.map(&:id).uniq
            @race_results = races.map(&:race_results).flatten
            @drivers = Driver.where(id: driver_ids, active: active_drivers).order(peak_elo: :desc).first(10)
        else
            @drivers = Driver.where(first_race_date: Date.new(1980,1,1)..Date.today, active: true).order(peak_elo: :desc).first(10)
        end
    end

    def peak_elo
        @drivers = Driver.where(first_race_date: Date.new(1980,1,1)..Date.today, active: true).order(peak_elo: :desc).first(10)
        @race_results = Driver.all.map { |driver| driver.peak_elo_race_result }.sort_by { |race_result| -race_result.new_elo }
    end

    def current_active_elo
        @drivers = Driver.active.order(elo: :desc)
    end
end
