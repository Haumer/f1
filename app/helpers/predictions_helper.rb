module PredictionsHelper
  # Converts {text|/path} tokens in reasoning text into links.
  # Example: "Won {here in 2024|/races/42} with Ferrari" →
  #          "Won <a href="/races/42">here in 2024</a> with Ferrari"
  def linkify_reasoning(text)
    return "" if text.blank?

    html = text.gsub(/\{([^|}]+)\|([^}]+)\}/) do
      label = $1
      path = $2
      external = path.start_with?("http")
      opts = { class: "pn-inline-link" }
      opts[:target] = "_blank" if external
      opts[:rel] = "noopener" if external
      link_to(label, path, **opts)
    end

    html.html_safe
  end
end
