class RaceResultsController < ApplicationController
    def index
        redirect_to races_path
    end

    def show
        @race_result = RaceResult.find(params[:id])
    end
end
