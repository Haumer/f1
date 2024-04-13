class RacesController < ApplicationController

    def show
        @race = Race.find(params[:id])
        @previous_race = @race.previous_race
        @next_race = @race.next_race
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
            @races = Race.where(year: (2000..2024).to_a).sorted_by_most_recent
        end
    end

    def highest_elo
        @race_results = Race.sorted.map { |race| race.highest_elo_race_result }.reject(&:blank?).reverse
    end

    def podiums

    end

    def winners
        @champ_race_results = Driver::CHAMPIONS.map do |champ|
            RaceResult.where(champ)
        end
    end
end
