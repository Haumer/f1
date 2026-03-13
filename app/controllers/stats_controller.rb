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

  ERAS = {
    "Pioneers"     => 1950..1969,
    "Ground Effect" => 1970..1989,
    "Modern"       => 1990..2009,
    "Hybrid"       => 2010..2099
  }.freeze

  def champion_timeline
    standings = Driver.champion_standings.to_a
    seasons_by_year = Season.all.index_by { |s| s.year.to_i }

    # Build reigns with constructor colors
    @reigns = []
    standings.group_by(&:driver).each do |driver, titles|
      years = titles.sort_by { |t| t.race.season.year.to_i }
      years.each do |t|
        year = t.race.season.year.to_i
        season = seasons_by_year[year]
        constructor = season ? driver.constructor_for(season) : nil
        color = constructor ? (Constructor::COLORS[constructor.constructor_ref.to_sym] || driver.color) : driver.color

        last = @reigns.last
        if last && last[:driver].id == driver.id && last[:end_year] == year - 1 && last[:color] == color
          last[:end_year] = year
          last[:titles] += 1
        else
          @reigns << {
            driver: driver,
            start_year: year,
            end_year: year,
            titles: 1,
            constructor: constructor,
            color: color
          }
        end
      end
    end

    @reigns.sort_by! { |r| r[:start_year] }
  end

  def race_wins
    base = Driver.includes(:countries)

    # Era filter
    @eras = ERAS
    @active_era = params[:era]
    if @active_era.present? && (range = ERAS[@active_era])
      # Driver active during this era: career overlaps with the range
      base = base.where("first_race_date <= ? AND last_race_date >= ?",
                        Date.new(range.last, 12, 31), Date.new(range.first, 1, 1))
    end

    @win_drivers = base.where("wins > 0").order(wins: :desc).to_a
    @podium_drivers = base.where("podiums > 0").order(podiums: :desc).to_a


    @win_milestones = build_milestones(@win_drivers, :wins, [
      { threshold: 100, label: "100+ wins" },
      { threshold: 50,  label: "50+ wins" },
      { threshold: 25,  label: "25+ wins" },
      { threshold: 10,  label: "10+ wins" },
      { threshold: 5,   label: "5+ wins" },
      { threshold: 4,   label: "4+ wins" },
      { threshold: 3,   label: "3+ wins" },
      { threshold: 2,   label: "2+ wins" },
      { threshold: 1,   label: "1+ win" },
    ])

    @podium_milestones = build_milestones(@podium_drivers, :podiums, [
      { threshold: 200, label: "200+ podiums" },
      { threshold: 150, label: "150+ podiums" },
      { threshold: 100, label: "100+ podiums" },
      { threshold: 50,  label: "50+ podiums" },
      { threshold: 25,  label: "25+ podiums" },
      { threshold: 10,  label: "10+ podiums" },
      { threshold: 5,   label: "5+ podiums" },
      { threshold: 4,   label: "4+ podiums" },
      { threshold: 3,   label: "3+ podiums" },
      { threshold: 2,   label: "2+ podiums" },
      { threshold: 1,   label: "1+ podium" },
    ])
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

  # Each driver appears only in their highest milestone bracket
  def build_milestones(drivers, field, tiers)
    seen = Set.new
    tiers.map do |m|
      qualified = drivers.select { |d| d.send(field) >= m[:threshold] }
      unique = qualified.reject { |d| seen.include?(d.id) }
      seen.merge(unique.map(&:id))
      m.merge(count: qualified.size, drivers: unique)
    end
  end

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
