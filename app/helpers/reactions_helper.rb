module ReactionsHelper
  # Renders the polymorphic reaction bar. Silently no-ops if reactable is nil.
  def reaction_bar(reactable, size: :sm)
    return if reactable.nil?

    render "reactions/bar", reactable: reactable, size: size
  end

  def reaction_bar_dom_id(reactable)
    "reactions_#{reactable.class.name.underscore}_#{reactable.id}"
  end
end
