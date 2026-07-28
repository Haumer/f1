class ReactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_reactable
  before_action :validate_kind

  # POST /reactions/:reactable_type/:reactable_id/toggle
  # Toggles a reaction of the given kind for the current user on the reactable.
  # Responds with Turbo Stream to replace the reaction bar in place.
  def toggle
    existing = @reactable.reactions.find_by(user: current_user, kind: params[:kind])
    if existing
      existing.destroy
    else
      @reactable.reactions.create!(user: current_user, kind: params[:kind])
    end
    # Bust memoized counts so the fresh partial reflects the update
    @reactable.instance_variable_set(:@reaction_counts, nil)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          reaction_bar_dom_id(@reactable),
          partial: "reactions/bar",
          locals: { reactable: @reactable }
        )
      end
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  REACTABLE_TYPES = {
    "Prediction" => Prediction,
    "RacePick" => RacePick,
    "FantasyStockHolding" => FantasyStockHolding,
    "DriverPreferenceSession" => DriverPreferenceSession
  }.freeze

  def load_reactable
    klass = REACTABLE_TYPES[params[:reactable_type]]
    return head :not_found unless klass

    @reactable = klass.find(params[:reactable_id])
  end

  def validate_kind
    return if Reaction::KINDS.include?(params[:kind])

    head :bad_request
  end

  def reaction_bar_dom_id(reactable)
    "reactions_#{reactable.class.name.underscore}_#{reactable.id}"
  end
  helper_method :reaction_bar_dom_id
end
