module RaceDetailsHelper
  def result_detail_fields(result, session:, constructor: nil, standing: nil)
    fields = { "Team" => constructor&.name || "Not recorded" }
    if session == :qualifying
      fields.merge!("Q1" => result.q1.presence || "No time recorded", "Q2" => result.q2.presence || "No time recorded", "Q3" => result.q3.presence || "No time recorded")
    else
      grid = result.grid.to_i
      changed = grid - result.position_order.to_i if grid.positive? && result.position_order.to_i.positive? && result.classified?
      fields.merge!("Grid" => (grid.positive? ? "P#{grid}" : "Not recorded / pit lane"),
                    "Places gained" => (changed ? format("%+d", changed) : "—"),
                    "Points" => format_points(result.points),
                    "Status" => result.status&.status_type || "Not recorded")
      if standing
        fields.merge!("Season points" => format_points(standing.points), "Season rank" => "P#{standing.position}")
      end
    end
    fields
  end

  def missing_session_message(race, session)
    starts_at = { race: race.starts_at, qualifying: race.quali_starts_at, sprint: race.sprint_starts_at }.fetch(session)
    label = session.to_s.capitalize
    return "#{label} has not started. Results will appear here after the session." if starts_at && starts_at > Time.current
    return "Awaiting #{session} results. No results have been recorded yet." if starts_at && starts_at > 6.hours.ago
    return "#{label} results are not available yet; the session time is not recorded." if !starts_at && race.date >= Date.current

    "#{label} results are unavailable for this race in our data."
  end
end
