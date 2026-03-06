class StatsController < ApplicationController
  def index
    set_current_champion_accent
  end

  def elo_milestones
    new_elo_col = Setting.elo_column(:new_elo)
    old_elo_col = Setting.elo_column(:old_elo)

    # Biggest single-race Elo gain
    @biggest_gains = RaceResult.where.not(new_elo_col => nil, old_elo_col => nil)
                  .order(Arel.sql("(#{new_elo_col} - #{old_elo_col}) DESC"))
                  .limit(10)
                  .includes(:driver, :constructor, race: :circuit)

    # Biggest single-race Elo drop
    @biggest_drops = RaceResult.where.not(new_elo_col => nil, old_elo_col => nil)
                  .order(Arel.sql("(#{new_elo_col} - #{old_elo_col}) ASC"))
                  .limit(10)
                  .includes(:driver, :constructor, race: :circuit)

    # Highest Elo entering a race
    @highest_entering = RaceResult.where.not(old_elo_col => nil)
                     .order(old_elo_col => :desc)
                     .limit(10)
                     .includes(:driver, :constructor, race: :circuit)

    # Fastest risers: biggest Elo gain in first 20 races
    @fastest_risers = compute_fastest_risers(new_elo_col, old_elo_col)
  end

  def fan_standings
    season = current_season
    @constructors = Constructor.where(active: true).order(:name).map do |c|
      fans = User.joins(:constructor_supports)
                 .where(constructor_supports: { constructor: c, active: true, season: season })
                 .distinct.to_a
      { constructor: c, fans: fans, count: fans.size }
    end
    @constructors.sort_by! { |c| [-c[:count], c[:constructor].name] }
    @total_fans = @constructors.sum { |c| c[:count] }
  end

  def badges
    # Group badges by type, sorted by value (descending where numeric)
    all_badges = DriverBadge.includes(:driver).order(:key, :id)

    @badge_groups = all_badges.group_by(&:key).map do |key, badges|
      sample = badges.first
      sorted = badges.sort_by do |b|
        val = b.value.to_s.gsub(/[^0-9.\-]/, "")
        val.present? ? -val.to_f : 0
      end
      { key: key, label: sample.label.sub(/ of .*/, ""), icon: sample.icon, color: sample.color, badges: sorted }
    end

    # Merge circuit_king variants into one group
    circuit_kings = @badge_groups.select { |g| g[:key].start_with?("circuit_king_") }
    if circuit_kings.any?
      merged = {
        key: "circuit_king",
        label: "King of [Circuit]",
        icon: "fa-solid fa-crown",
        color: "gold",
        badges: circuit_kings.flat_map { |g| g[:badges] }.sort_by { |b| -b.value.to_i }
      }
      @badge_groups.reject! { |g| g[:key].start_with?("circuit_king_") }
      @badge_groups.unshift(merged)
    end

    # Sort groups by badge order
    order = DriverBadges::BADGE_ORDER.map(&:to_s)
    @badge_groups.sort_by! { |g| order.index(g[:key]) || 99 }

    @total_badges = all_badges.size
    @total_drivers = all_badges.select(:driver_id).distinct.count
  end

  private

  def compute_fastest_risers(new_elo_col, old_elo_col)
    # Single query: for each driver with 20+ results, get their first old_elo and 20th new_elo
    sql = <<~SQL
      WITH ranked AS (
      SELECT race_results.driver_id,
           race_results.#{old_elo_col},
           race_results.#{new_elo_col},
           ROW_NUMBER() OVER (PARTITION BY race_results.driver_id ORDER BY races.date ASC) AS rn,
           COUNT(*) OVER (PARTITION BY race_results.driver_id) AS total
      FROM race_results
      INNER JOIN races ON races.id = race_results.race_id
      WHERE race_results.#{old_elo_col} IS NOT NULL
        AND race_results.#{new_elo_col} IS NOT NULL
      )
      SELECT driver_id,
         MAX(CASE WHEN rn = 1 THEN #{old_elo_col} END) AS start_elo,
         MAX(CASE WHEN rn = 20 THEN #{new_elo_col} END) AS end_elo
      FROM ranked
      WHERE total >= 20 AND rn IN (1, 20)
      GROUP BY driver_id
      HAVING MAX(CASE WHEN rn = 20 THEN #{new_elo_col} END) IS NOT NULL
    SQL

    rows = ActiveRecord::Base.connection.select_all(sql)
    driver_ids = rows.map { |r| r["driver_id"] }
    drivers_by_id = Driver.where(id: driver_ids).includes(:countries).index_by(&:id)

    risers = rows.filter_map do |row|
      driver = drivers_by_id[row["driver_id"]]
      next unless driver
      start_elo = row["start_elo"].to_f
      end_elo = row["end_elo"].to_f
      { driver: driver, rise: (end_elo - start_elo).round, start_elo: start_elo.round, end_elo: end_elo.round }
    end

    risers.sort_by { |r| -r[:rise] }.first(10)
  end
end
