class ConstructorsController < ApplicationController
    def show
        @constructor = Constructor.find(params[:id])
    end
end
