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

  include Stats
  include RaceBadges
  include EloBadges
  include CareerBadges
  include DubiousBadges

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

  def add_badge(key, label:, description:, icon:, color:, value:)
    @badges << Badge.new(key: key, label: label, description: description, icon: icon, color: color, value: value)
  end

  def sort_badges
    @badges.sort_by! { |b| BADGE_ORDER.index(b.key.to_s.sub(/^circuit_king_.*/, "circuit_king").to_sym) || 99 }
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

      add_badge(:"circuit_king_#{circuit.id}",
        label: "King of #{circuit.name}", description: "#{win_count} wins at #{circuit.name}",
        icon: "fa-solid fa-crown", color: "gold", value: win_count)
    end
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
end
