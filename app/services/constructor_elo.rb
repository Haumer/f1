class ConstructorElo
  STARTING_ELO = 1000.0
  K_FACTOR = 4.0

  # Calculate and update constructor Elo for a single race.
  # Uses best finishing position of each constructor's drivers.
  def self.update_for_race(race)
    results = race.race_results.includes(:constructor).to_a
    return if results.empty?

    # Best finish per constructor
    constructor_results = results.group_by(&:constructor_id)
    constructor_places = constructor_results.map do |constructor_id, rrs|
      best = rrs.min_by { |rr| rr.position_order || 999 }
      constructor = best.constructor
      [constructor, best.position_order || 999]
    end

    # Run Elo matchups between all constructor pairs
    adjustments = Hash.new(0.0)
    constructor_places.combination(2) do |(c1, place1), (c2, place2)|
      rating1 = c1.elo || STARTING_ELO
      rating2 = c2.elo || STARTING_ELO

      expected1 = 1.0 / (1 + (10 ** ((rating2 - rating1) / 400.0)))
      actual1 = place1 < place2 ? 1.0 : (place1 == place2 ? 0.5 : 0.0)

      adj = K_FACTOR * (actual1 - expected1)
      adjustments[c1.id] += adj
      adjustments[c2.id] -= adj
    end

    # Apply adjustments
    constructor_places.each do |constructor, _|
      new_elo = (constructor.elo || STARTING_ELO) + adjustments[constructor.id]
      current_peak = constructor.peak_elo || 0
      constructor.update(elo: new_elo, peak_elo: [new_elo, current_peak].max)
    end
  end

  # Recalculate all constructor Elo from scratch
  def self.recalculate_all!
    Constructor.update_all(elo: STARTING_ELO, peak_elo: STARTING_ELO)

    races = Race.joins(:race_results).distinct.includes(:race_results).order(date: :asc)
    races.find_each do |race|
      update_for_race(race)
    end

    puts "Constructor Elo calculated for #{races.count} races"
  end
end
