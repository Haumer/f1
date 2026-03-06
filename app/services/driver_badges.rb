class DriverBadges
  Badge = Struct.new(:key, :label, :description, :icon, :color, :value, keyword_init: true)

  BADGE_ORDER = %i[
    circuit_king consecutive_wins consecutive_podiums pole_to_win
    comeback_king recovery_drive elo_rocket elo_freefall
    rookie_win rookie_podium
    one_hit_wonder century_club finishes_milestone loyal_servant dynamic_duo
    iron_man points_machine clean_racer
    crash_king mechanical_magnet backmarker lapped
    constructor_nomad bridesmaid fourth_place_specialist
    hulkenberg_award
  ].freeze

  attr_reader :badges

  def initialize(driver:, race_results: nil, driver_standings: nil, min_year: nil)
    @driver = driver
    @min_year = min_year || Setting.badge_min_year
    all_results = race_results || driver.race_results.to_a
    all_standings = driver_standings || driver.driver_standings.to_a
    @race_results = all_results.select { |rr| rr.race.date.year >= @min_year }
    @driver_standings = all_standings.select { |ds| ds.race.date.year >= @min_year }
    @sorted_results = @race_results.sort_by { |rr| rr.race.date }
    @badges = []
    compute_all
    sort_badges
  end

  def persist!
    @driver.badges.delete_all
    @badges.each do |badge|
      @driver.badges.create!(
        key: badge.key.to_s,
        label: badge.label,
        description: badge.description,
        icon: badge.icon,
        color: badge.color,
        value: badge.value.to_s
      )
    end
  end

  def self.compute_all_drivers!
    drivers = Driver.includes(
      driver_standings: { race: :season },
      race_results: { race: :circuit, constructor: [], status: [] }
    ).where("CAST(number_of_races AS INTEGER) > 0")

    DriverBadge.delete_all
    count = 0

    drivers.find_each do |driver|
      service = new(
        driver: driver,
        race_results: driver.race_results.to_a,
        driver_standings: driver.driver_standings.to_a
      )
      service.persist!
      count += service.badges.size
    end

    assign_tiers!
    count
  end

  # Rank badges within each key group and assign gold/silver/bronze to top 3
  def self.assign_tiers!
    DriverBadge.update_all(tier: nil)

    DriverBadge.select(:key).distinct.pluck(:key).each do |key|
      badges = DriverBadge.where(key: key).to_a

      sorted = badges.sort_by do |b|
        val = b.value.to_s.gsub(/[^0-9.\-]/, "")
        val.present? ? -val.to_f : 0
      end

      # For "undesirable" badges, higher value is worse — but the leader
      # in the category still gets gold (it's an achievement either way)
      sorted.first(3).each_with_index do |badge, i|
        tier = %w[gold silver bronze][i]
        badge.update_column(:tier, tier)
      end
    end
  end

  private

  def compute_all
    # Prestigious
    check_consecutive_wins
    check_consecutive_podiums
    check_circuit_king
    check_recovery_drive
    check_pole_to_win
    check_comeback_king
    check_elo_rocket
    check_elo_freefall
    check_rookie_win
    check_rookie_podium
    check_one_hit_wonder
    check_century_club
    check_finishes_milestone

    # Loyalty
    check_loyal_servant
    check_dynamic_duo

    # Positive traits
    check_iron_man
    check_points_machine
    check_clean_racer

    # Undesirable
    check_crash_king
    check_mechanical_magnet
    check_backmarker
    check_lapped

    # Character
    check_constructor_nomad
    check_bridesmaid
    check_fourth_place_specialist
    check_hulkenberg_award
  end

  def sort_badges
    @badges.sort_by! { |b| BADGE_ORDER.index(b.key.to_s.sub(/^circuit_king_.*/, "circuit_king").to_sym) || 99 }
  end

  # ── STREAKS ──────────────────────────────────────────

  def check_consecutive_wins
    streak = longest_streak(@sorted_results) { |rr| rr.position_order == 1 }
    return unless streak >= 3

    @badges << Badge.new(
      key: :consecutive_wins,
      label: "On Fire",
      description: "#{streak} consecutive race wins",
      icon: "fa-solid fa-fire",
      color: "gold",
      value: streak
    )
  end

  def check_consecutive_podiums
    streak = longest_streak(@sorted_results) { |rr| rr.position_order && rr.position_order <= 3 }
    return unless streak >= 5

    @badges << Badge.new(
      key: :consecutive_podiums,
      label: "Podium Machine",
      description: "#{streak} consecutive podium finishes",
      icon: "fa-solid fa-bolt-lightning",
      color: "bronze",
      value: streak
    )
  end

  # ── CIRCUIT DOMINANCE ────────────────────────────────

  def check_circuit_king
    wins_by_circuit = @sorted_results
      .select { |rr| rr.position_order == 1 }
      .group_by { |rr| rr.race.circuit }

    wins_by_circuit.each do |circuit, results|
      win_count = results.size
      next unless win_count >= 3

      top_winners = RaceResult.joins(:race)
        .where(races: { circuit_id: circuit.id }, position_order: 1)
        .where("EXTRACT(YEAR FROM races.date) >= ?", @min_year)
        .group(:driver_id)
        .order("count_all DESC")
        .limit(3)
        .count

      sorted = top_winners.sort_by { |_, count| -count }
      rank = sorted.index { |did, _| did == @driver.id }
      next unless rank && rank < 3

      @badges << Badge.new(
        key: :"circuit_king_#{circuit.id}",
        label: "King of #{circuit.name}",
        description: "#{win_count} wins at #{circuit.name}",
        icon: "fa-solid fa-crown",
        color: "gold",
        value: win_count
      )
    end
  end

  # ── RACE CRAFT ───────────────────────────────────────

  def check_recovery_drive
    recoveries = @sorted_results.select do |rr|
      rr.grid && rr.grid >= 15 && rr.position_order && rr.position_order <= 3
    end
    return unless recoveries.any?

    best = recoveries.max_by { |rr| rr.grid - rr.position_order }
    gained = best.grid - best.position_order

    @badges << Badge.new(
      key: :recovery_drive,
      label: "Recovery Artist",
      description: "Started P#{best.grid}, finished P#{best.position_order} at #{best.race.circuit.name}",
      icon: "fa-solid fa-heart-pulse",
      color: "green",
      value: "+#{gained}"
    )
  end

  def check_pole_to_win
    pole_wins = @sorted_results.count { |rr| rr.grid == 1 && rr.position_order == 1 }
    return unless pole_wins >= 3

    @badges << Badge.new(
      key: :pole_to_win,
      label: "Lights to Flag",
      description: "#{pole_wins} pole-to-victory conversions",
      icon: "fa-solid fa-flag-checkered",
      color: "red",
      value: pole_wins
    )
  end

  def check_comeback_king
    valid = @sorted_results.select { |rr| rr.grid && rr.grid > 0 && rr.position_order && rr.position_order > 0 }
    best = valid.max_by { |rr| rr.grid - rr.position_order }
    return unless best && (best.grid - best.position_order) >= 15

    gained = best.grid - best.position_order
    @badges << Badge.new(
      key: :comeback_king,
      label: "Comeback King",
      description: "Gained #{gained} places in a single race (P#{best.grid} → P#{best.position_order})",
      icon: "fa-solid fa-jet-fighter-up",
      color: "blue",
      value: "+#{gained}"
    )
  end

  # ── ELO ──────────────────────────────────────────────

  def check_elo_rocket
    return if @sorted_results.empty?

    best = @sorted_results.max_by { |rr| rr.display_elo_diff || 0 }
    return unless best && (best.display_elo_diff || 0) >= 80

    @badges << Badge.new(
      key: :elo_rocket,
      label: "Elo Rocket",
      description: "+#{best.display_elo_diff.round(1)} Elo in a single race at #{best.race.circuit.name}",
      icon: "fa-solid fa-rocket",
      color: "orange",
      value: "+#{best.display_elo_diff.round(1)}"
    )
  end

  def check_elo_freefall
    return if @sorted_results.empty?

    worst = @sorted_results.min_by { |rr| rr.display_elo_diff || 0 }
    return unless worst && (worst.display_elo_diff || 0) <= -80

    @badges << Badge.new(
      key: :elo_freefall,
      label: "Elo Crater",
      description: "#{worst.display_elo_diff.round(1)} Elo in a single race at #{worst.race.circuit.name}",
      icon: "fa-solid fa-meteor",
      color: "crimson",
      value: worst.display_elo_diff.round(1)
    )
  end

  # ── ROOKIE SEASON ───────────────────────────────────

  def rookie_season_results
    @rookie_season_results ||= begin
      # Use ALL results (unfiltered by min_year) to find actual debut year
      all_sorted = @driver.race_results.to_a.sort_by { |rr| rr.race.date }
      return [] if all_sorted.empty?
      debut_year = all_sorted.first.race.date.year
      # Only award if debut is within the badge filter window
      return [] if debut_year < @min_year
      @sorted_results.select { |rr| rr.race.date.year == debut_year }
    end
  end

  def check_rookie_win
    wins = rookie_season_results.select { |rr| rr.position_order == 1 }
    return unless wins.any?

    first_win = wins.first
    @badges << Badge.new(
      key: :rookie_win,
      label: "Rookie Winner",
      description: "#{wins.size} win#{'s' if wins.size > 1} in debut season (#{first_win.race.date.year})",
      icon: "fa-solid fa-seedling",
      color: "gold",
      value: wins.size
    )
  end

  def check_rookie_podium
    podiums = rookie_season_results.select { |rr| rr.position_order && rr.position_order <= 3 }
    return unless podiums.any?
    # Skip if they already have a rookie win — podium is implied
    wins = podiums.count { |rr| rr.position_order == 1 }
    return if wins > 0

    @badges << Badge.new(
      key: :rookie_podium,
      label: "Rookie Podium",
      description: "#{podiums.size} podium#{'s' if podiums.size > 1} in debut season (#{podiums.first.race.date.year})",
      icon: "fa-solid fa-seedling",
      color: "green",
      value: podiums.size
    )
  end

  # ── CAREER MILESTONES ────────────────────────────────

  def check_one_hit_wonder
    wins = total_wins
    total = total_races
    return unless wins == 1 && total >= 20

    win_rr = @sorted_results.find { |rr| rr.position_order == 1 }
    where = win_rr ? " at #{win_rr.race.circuit.name}" : ""

    @badges << Badge.new(
      key: :one_hit_wonder,
      label: "One Hit Wonder",
      description: "1 win in #{total} races#{where}",
      icon: "fa-solid fa-dice-one",
      color: "purple",
      value: "1/#{total}"
    )
  end

  def check_century_club
    total = total_races
    return unless total >= 100

    tier, icon = if total >= 300
                   ["Triple Century", "fa-solid fa-certificate"]
                 elsif total >= 200
                   ["Double Century", "fa-solid fa-award"]
                 else
                   ["Century Club", "fa-solid fa-medal"]
                 end

    @badges << Badge.new(
      key: :century_club,
      label: tier,
      description: "#{total} career race starts",
      icon: icon,
      color: "silver",
      value: total
    )
  end

  def check_finishes_milestone
    finished = total_finished
    return unless finished >= 50

    label, icon = if finished >= 200
                    ["200 Finishes", "fa-solid fa-star"]
                  elsif finished >= 150
                    ["150 Finishes", "fa-solid fa-certificate"]
                  elsif finished >= 100
                    ["100 Finishes", "fa-solid fa-award"]
                  else
                    ["50 Finishes", "fa-solid fa-medal"]
                  end

    @badges << Badge.new(
      key: :finishes_milestone,
      label: label,
      description: "#{finished} classified race finishes",
      icon: icon,
      color: "green",
      value: finished
    )
  end

  # ── LOYALTY ──────────────────────────────────────────

  def check_loyal_servant
    return if @sorted_results.size < 50

    max_streak = 0
    max_constructor = nil
    cur_streak = 0
    cur_constructor_id = nil

    @sorted_results.each do |rr|
      if rr.constructor_id == cur_constructor_id
        cur_streak += 1
      else
        cur_streak = 1
        cur_constructor_id = rr.constructor_id
      end
      if cur_streak > max_streak
        max_streak = cur_streak
        max_constructor = rr.constructor
      end
    end

    return unless max_streak >= 80

    pct = (max_streak.to_f / total_races * 100).round(0)

    @badges << Badge.new(
      key: :loyal_servant,
      label: "Loyal Servant",
      description: "#{max_streak} consecutive races with #{max_constructor&.name} (#{pct}% of career)",
      icon: "fa-solid fa-handshake",
      color: "blue",
      value: max_streak
    )
  end

  def check_dynamic_duo
    # Find teammate with most shared races at same constructor
    race_ids = @sorted_results.map(&:race_id)
    return if race_ids.empty?

    # Batch-load all race results for these races to avoid N+1
    constructor_by_race = @sorted_results.each_with_object({}) { |rr, h| h[rr.race_id] = rr.constructor_id }

    all_teammate_results = RaceResult.where(race_id: race_ids)
                                     .where.not(driver_id: @driver.id)
                                     .pluck(:race_id, :driver_id, :constructor_id)

    teammate_counts = Hash.new(0)
    all_teammate_results.each do |race_id, driver_id, constructor_id|
      teammate_counts[driver_id] += 1 if constructor_id == constructor_by_race[race_id]
    end

    return if teammate_counts.empty?

    best_id, count = teammate_counts.max_by { |_, c| c }
    return unless count >= 60

    teammate = Driver.find_by(id: best_id)
    return unless teammate

    @badges << Badge.new(
      key: :dynamic_duo,
      label: "Dynamic Duo",
      description: "#{count} races alongside #{teammate.forename.first}.#{teammate.surname}",
      icon: "fa-solid fa-user-group",
      color: "blue",
      value: count
    )
  end

  # ── POSITIVE TRAITS ──────────────────────────────────

  def check_iron_man
    total = total_races
    finished = total_finished
    return unless total >= 50 && finished.to_f / total >= 0.90

    rate = (finished.to_f / total * 100).round(1)
    @badges << Badge.new(
      key: :iron_man,
      label: "Iron Man",
      description: "#{rate}% finish rate over #{total} races",
      icon: "fa-solid fa-shield-halved",
      color: "steel",
      value: "#{rate}%"
    )
  end

  def check_points_machine
    total = total_races
    return unless total >= 50

    points_finishes = @sorted_results.count { |rr| rr.position_order && rr.position_order <= 10 }
    rate = (points_finishes.to_f / total * 100).round(1)
    return unless rate >= 70

    @badges << Badge.new(
      key: :points_machine,
      label: "Points Machine",
      description: "#{rate}% points-scoring rate (#{points_finishes}/#{total} races)",
      icon: "fa-solid fa-bullseye",
      color: "blue",
      value: "#{rate}%"
    )
  end

  def check_clean_racer
    total = total_races
    crashes = total_crashes
    return unless total >= 80 && crashes <= 5

    @badges << Badge.new(
      key: :clean_racer,
      label: "Clean Racer",
      description: "Only #{crashes} accident DNFs in #{total} races",
      icon: "fa-solid fa-broom",
      color: "green",
      value: crashes
    )
  end

  # ── UNDESIRABLE ──────────────────────────────────────

  def check_crash_king
    crashes = total_crashes
    total = total_races
    return unless crashes >= 25

    rate = (crashes.to_f / total * 100).round(1)
    @badges << Badge.new(
      key: :crash_king,
      label: "The Maldonado",
      description: "#{crashes} accident-related DNFs (#{rate}% of races)",
      icon: "fa-solid fa-car-burst",
      color: "crimson",
      value: crashes
    )
  end

  def check_mechanical_magnet
    mech = total_mechanical
    total = total_races
    return unless mech >= 30

    rate = (mech.to_f / total * 100).round(1)
    @badges << Badge.new(
      key: :mechanical_magnet,
      label: "Cursed Machinery",
      description: "#{mech} mechanical DNFs (#{rate}% of races)",
      icon: "fa-solid fa-screwdriver-wrench",
      color: "crimson",
      value: mech
    )
  end

  def check_backmarker
    total = total_races
    outside = total_outside_top_ten
    return unless total >= 80 && outside.to_f / total >= 0.60

    rate = (outside.to_f / total * 100).round(1)
    @badges << Badge.new(
      key: :backmarker,
      label: "Off the Pace",
      description: "#{rate}% of races finished outside the top 10 (#{outside}/#{total})",
      icon: "fa-solid fa-face-sad-tear",
      color: "gray",
      value: "#{rate}%"
    )
  end

  def check_lapped
    lapped = total_lapped
    total = total_races
    return unless lapped >= 50

    rate = (lapped.to_f / total * 100).round(1)
    @badges << Badge.new(
      key: :lapped,
      label: "Blue Flag Special",
      description: "Lapped in #{lapped} races (#{rate}% of career)",
      icon: "fa-solid fa-flag",
      color: "gray",
      value: lapped
    )
  end

  # ── CHARACTER ────────────────────────────────────────

  def check_constructor_nomad
    teams = @race_results.filter_map(&:constructor).uniq
    return unless teams.size >= 4

    label = teams.size >= 7 ? "Journeyman" : "Team Hopper"
    @badges << Badge.new(
      key: :constructor_nomad,
      label: label,
      description: "Raced for #{teams.size} different constructors",
      icon: "fa-solid fa-shuffle",
      color: "purple",
      value: teams.size
    )
  end

  def check_bridesmaid
    second_places = total_second_places
    return unless second_places >= 20

    @badges << Badge.new(
      key: :bridesmaid,
      label: "Always the Bridesmaid",
      description: "#{second_places} career 2nd-place finishes",
      icon: "fa-solid fa-heart-crack",
      color: "silver",
      value: second_places
    )
  end

  def check_fourth_place_specialist
    fourths = total_fourth_places
    return unless fourths >= 20

    @badges << Badge.new(
      key: :fourth_place_specialist,
      label: "Wooden Spoon",
      description: "#{fourths} career 4th-place finishes — so close to the podium",
      icon: "fa-solid fa-face-meh",
      color: "gray",
      value: fourths
    )
  end

  def check_hulkenberg_award
    total = total_races
    podiums = total_podiums
    return unless total >= 50 && podiums == 0

    @badges << Badge.new(
      key: :hulkenberg_award,
      label: "The Hülkenberg",
      description: "#{total} races without a podium finish",
      icon: "fa-solid fa-ghost",
      color: "gray",
      value: total
    )
  end

  # ── COMPUTED STATS (from filtered results) ──────────

  def total_races
    @sorted_results.size
  end

  def total_wins
    @sorted_results.count { |rr| rr.position_order == 1 }
  end

  def total_podiums
    @sorted_results.count { |rr| rr.position_order && rr.position_order <= 3 }
  end

  def total_second_places
    @sorted_results.count { |rr| rr.position_order == 2 }
  end

  def total_fourth_places
    @sorted_results.count { |rr| rr.position_order == 4 }
  end

  def total_finished
    @sorted_results.count { |rr| rr.status&.finished? || rr.status&.lapped? }
  end

  def total_crashes
    @sorted_results.count { |rr| rr.status&.accident? || rr.status&.retired? || rr.status&.health? }
  end

  def total_mechanical
    @sorted_results.count { |rr| rr.status&.technical? }
  end

  def total_outside_top_ten
    @sorted_results.count { |rr| rr.position_order && rr.position_order > 10 }
  end

  def total_lapped
    @sorted_results.count { |rr| rr.status&.lapped? }
  end

  # ── UTILS ────────────────────────────────────────────

  def longest_streak(results)
    max = 0
    current = 0
    results.each do |rr|
      if yield(rr)
        current += 1
        max = current if current > max
      else
        current = 0
      end
    end
    max
  end
end
