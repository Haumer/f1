class CircuitsController < ApplicationController
  def index
    @calendar_races = current_season&.races
              &.includes(:circuit, race_results: [:driver, :constructor])
              &.order(:date) || Race.none
    @calendar_circuit_ids = @calendar_races.map(&:circuit_id)
    @season_year = current_season&.year

    # Winners resolved once from the already-included results. `find_by` on the
    # association would issue a query per race and defeat the includes above.
    @winners_by_race_id = @calendar_races.each_with_object({}) do |race, hash|
      hash[race.id] = race.race_results.find { |rr| rr.position_order == 1 }
    end

    @calendar_map = build_calendar_map

    @circuits = Circuit.left_joins(:races)
              .select("circuits.*, COUNT(races.id) as races_count")
              .group("circuits.id")
              .having("COUNT(races.id) > 0")
              .order("races_count DESC, circuits.name ASC")
  end

  def show
    @circuit = Circuit.find_by!(circuit_ref: params[:id])
    set_circuit_accent(@circuit)
    @races = @circuit.races.includes(:season, race_results: [driver: :countries, constructor: [], status: []]).order(date: :desc)

    # Circuit stats
    @first_race_year = @races.last&.season&.year
    @latest_race_year = @races.first&.season&.year
    @highest_avg_elo_race = @races.select { |r| r.average_elo.present? }.max_by(&:average_elo)

    # Most successful driver (most wins at this circuit)
    all_results = @races.flat_map(&:race_results)
    wins_by_driver = all_results.select { |rr| rr.position_order == 1 }.group_by(&:driver)
    if wins_by_driver.any?
      @most_successful_driver, @most_successful_wins = wins_by_driver.max_by { |_, rrs| rrs.size }
    end

    # Top winners at this circuit (for expanded stats)
    @circuit_winners = wins_by_driver
      .map { |driver, rrs| { driver: driver, wins: rrs.size, years: rrs.map { |rr| rr.race.season&.year }.compact } }
      .sort_by { |w| -w[:wins] }
      .first(10)

    # Most successful constructor at this circuit
    wins_by_constructor = all_results.select { |rr| rr.position_order == 1 && rr.constructor }.group_by(&:constructor)
    if wins_by_constructor.any?
      @most_successful_constructor, @constructor_wins = wins_by_constructor.max_by { |_, rrs| rrs.size }
    end

    # Record Elo at circuit
    new_elo_col = Setting.elo_column(:new_elo).to_sym
    @record_elo_rr = all_results.compact.max_by { |rr| rr.send(new_elo_col) || 0 }

    # Circuit kings
    @circuit_kings = DriverBadge.circuit_kings_for(@circuit.id)

    # Podium data per race for the expanded race history
    @podiums_by_race = @races.each_with_object({}) do |race, hash|
      hash[race.id] = race.race_results
        .select { |rr| rr.position_order && rr.position_order <= 3 }
        .sort_by(&:position_order)
    end
  end
  private

  # The season as a journey: one stop per round in calendar order, plus the legs
  # between consecutive rounds. Only circuits with coordinates can be plotted —
  # every circuit currently has them, but a new one could land without.
  def build_calendar_map
    today = Setting.effective_today

    stops = @calendar_races.filter_map do |race|
      circuit = race.circuit
      next if circuit.lat.blank? || circuit.lng.blank?

      winner = race.date < today ? @winners_by_race_id[race.id] : nil

      {
        name: circuit.name,
        location: [circuit.location, circuit.country].compact_blank.join(", "),
        round: race.round,
        date: race.date.strftime("%b %-d"),
        coord: [circuit.lng, circuit.lat],
        path: circuit_path(circuit),
        past: race.date < today,
        winner: winner && "#{winner.driver.forename&.first}.#{winner.driver.surname}",
        color: winner && constructor_color(winner.constructor)
      }
    end

    return { stops: [], legs: [] } if stops.size < 2

    # The next round is the first stop that hasn't happened; its inbound leg is
    # the one worth animating.
    next_index = stops.index { |s| !s[:past] }

    legs = stops.each_cons(2).with_index.flat_map do |(from, to), i|
      state = if next_index && i + 1 == next_index then "next"
              elsif to[:past] then "done"
              else "upcoming"
              end

      antimeridian_split(from[:coord], to[:coord]).map do |coords, curved|
        { coords: coords, state: state, curved: curved }
      end
    end

    { stops: stops, legs: legs, next_index: next_index }
  end

  # A flight from Suzuka to Miami is shorter across the Pacific, but a line
  # drawn in projected coordinates goes the other way — backwards across
  # Eurasia. When the short path crosses the 180th meridian, cut the leg at the
  # map edge and resume on the far side so it reads as leaving one edge and
  # entering the other. Split halves are drawn straight; a curve would bow them
  # away from the edge and break the illusion.
  def antimeridian_split(from, to)
    lng1, lat1 = from
    lng2, lat2 = to
    delta = lng2 - lng1
    return [[[from, to], true]] if delta.abs <= 180

    eastward = delta.negative?          # short way runs east, off the right edge
    edge     = eastward ? 180.0 : -180.0
    span     = 360 - delta.abs          # length of the short path, in degrees
    fraction = (edge - lng1).abs / span
    lat_edge = (lat1 + (lat2 - lat1) * fraction).round(4)

    [
      [[from, [edge, lat_edge]], false],
      [[[-edge, lat_edge], to], false]
    ]
  end
end
