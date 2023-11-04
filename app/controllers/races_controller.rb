class RacesController < ApplicationController

    def show
        @race = Race.find(params[:id])
    end

    def index
        if params[:search].present?
            begin
                search_date = Date.parse(params[:search][:first_race_date])
            rescue => exception
                search_date = Date.new(1930,1,1)
            end
            @races = Race.sorted.reverse.where(date: search_date..Date.today)
        else
            @races = Race.sorted.reverse
        end
    end

    def highest_elo
        @race_results = Race.sorted.map { |race| race.highest_elo_race_result }.reject(&:blank?).reverse
    end

    def podiums

    end

    def winners
        @race_results = RaceResult.where(position_order: 1).sort_by { |race_result| race_result.race.date }.reverse
    end
end
