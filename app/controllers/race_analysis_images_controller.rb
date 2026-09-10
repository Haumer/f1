class RaceAnalysisImagesController < ApplicationController
  def show
    race = Race.includes(:circuit, :season).find(params[:id])
    analysis = RaceAnalysis.new(race: race)
    return head :not_found unless analysis.available?

    card = RaceAnalysisShare.new(analysis)
    expires_in 5.minutes, public: true
    return unless stale?(etag: card.fingerprint, public: true)

    png = Rails.cache.fetch(["race-analysis-og", card.fingerprint], expires_in: 1.day) do
      RaceAnalysisOgGenerator.new(card.payload).generate
    end
    send_data png, type: "image/png", disposition: "inline"
  end
end
