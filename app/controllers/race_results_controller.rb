class RaceResultsController < ApplicationController
    def show
        @race_result = RaceResult.find(params[:id])
    end
end
