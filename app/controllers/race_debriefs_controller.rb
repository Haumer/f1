class RaceDebriefsController < ApplicationController
  def show
    @race = Race.includes(:circuit, :season).find(params[:id])
    @analysis = RaceAnalysis.new(race: @race)
    @analysis_share = RaceAnalysisShare.new(@analysis) if @analysis.available?
    set_race_winner_accent(@race)
  end
end
