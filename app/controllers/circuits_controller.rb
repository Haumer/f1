class CircuitsController < ApplicationController
    def index
        @circuits = Circuit.order(name: :asc)
    end

    def show
        @circuit = Circuit.find(params[:id])
    end
end
