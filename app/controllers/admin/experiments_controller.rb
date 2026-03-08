module Admin
  class ExperimentsController < BaseController
    POINTS_TABLE = { 1 => 25, 2 => 18, 3 => 15, 4 => 12, 5 => 10, 6 => 8, 7 => 6, 8 => 4, 9 => 2, 10 => 1 }.freeze

    def index
      @available_years = Season.joins(races: :race_results).distinct.order(year: :desc).pluck(:year)
      @from_year = (params[:from] || @available_years.first).to_i
      @to_year   = (params[:to]   || @from_year).to_i
      @from_year, @to_year = @to_year, @from_year if @from_year > @to_year

      seasons = Season.where(year: @from_year..@to_year).order(:year)
      @multi_year = @from_year != @to_year

      # All races in range, ordered chronologically
      races_in_range = Race.where(season: seasons).joins(:race_results).distinct.order(:year, :round)
      @total_races = races_in_range.count
      @race_labels = races_in_range.pluck(:year, :round).map { |y, r| @multi_year ? "#{y} R#{r}" : "R#{r}" }

      results = RaceResult.joins(:race)
                          .where(races: { season_id: seasons.pluck(:id) })
                          .includes(:driver, :constructor, race: [:circuit, :season])

      # Build baseline: average finish position per grid slot (clean races only)
      clean_results = results.select { |rr| rr.position_order <= 15 && rr.grid > 0 }
      by_grid = clean_results.group_by(&:grid)
      @grid_baseline = {}
      by_grid.each do |grid, rrs|
        finishes = rrs.map(&:position_order)
        avg_finish = finishes.sum.to_f / finishes.size
        @grid_baseline[grid] = { avg_finish: avg_finish, avg_delta: grid - avg_finish, count: finishes.size }
      end

      # Points conversion baseline: average points scored per grid slot
      @grid_points_baseline = {}
      results.select { |rr| rr.grid > 0 }.group_by(&:grid).each do |grid, rrs|
        pts = rrs.map { |rr| rr.points.to_f }
        @grid_points_baseline[grid] = (pts.sum / pts.size).round(2)
      end

      # Constructor baseline: average finish per constructor in this period
      by_constructor = clean_results.group_by(&:constructor_id)
      @constructor_baseline = {}
      by_constructor.each do |cid, rrs|
        positions = rrs.map(&:position_order)
        @constructor_baseline[cid] = (positions.sum.to_f / positions.size).round(2)
      end

      by_driver = results.group_by(&:driver_id)

      @drivers_data = by_driver.map do |_driver_id, rrs|
        driver = rrs.first.driver
        constructor = rrs.last.constructor
        color = Constructor::COLORS[constructor&.constructor_ref&.to_sym] || "#888"
        code = driver.code || driver.surname[0..2].upcase

        sorted_rrs = rrs.sort_by { |rr| [rr.race.year, rr.race.round] }

        # Cumulative points chronologically
        cumulative = []
        running = 0.0
        sorted_rrs.each do |rr|
          running += rr.points.to_f
          label = @multi_year ? "#{rr.race.year} R#{rr.race.round}" : "R#{rr.race.round}"
          cumulative << { label: label, points: running }
        end

        # Grid-to-finish for clean races (position_order <= 15, grid > 0)
        clean_rrs = sorted_rrs.select { |rr| rr.position_order <= 15 && rr.grid > 0 }
        grid_finish_pairs = clean_rrs.map { |rr|
          [rr.grid, rr.position_order, "#{rr.race.year} R#{rr.race.round}"]
        }

        # Raw qualifying vs race delta
        deltas = clean_rrs.map { |rr| rr.grid - rr.position_order }
        avg_delta = deltas.any? ? (deltas.sum.to_f / deltas.size).round(2) : 0

        # Position-adjusted delta (vs field average for same grid slot)
        adjusted_deltas = clean_rrs.map { |rr|
          raw = rr.grid - rr.position_order
          baseline = @grid_baseline.dig(rr.grid, :avg_delta) || 0
          raw - baseline
        }
        avg_adjusted_delta = adjusted_deltas.any? ? (adjusted_deltas.sum.to_f / adjusted_deltas.size).round(2) : 0
        avg_grid = clean_rrs.any? ? (clean_rrs.sum(&:grid).to_f / clean_rrs.size).round(1) : 0

        # ── Season Momentum: rolling 5-race average position ──
        momentum = []
        window = 5
        sorted_rrs.each_with_index do |rr, i|
          start_i = [0, i - window + 1].max
          window_rrs = sorted_rrs[start_i..i]
          avg_pos = window_rrs.sum(&:position_order).to_f / window_rrs.size
          label = @multi_year ? "#{rr.race.year} R#{rr.race.round}" : "R#{rr.race.round}"
          momentum << { label: label, avg_pos: avg_pos.round(2) }
        end

        # ── Points Conversion by Grid Slot ──
        grid_with_results = sorted_rrs.select { |rr| rr.grid > 0 }
        by_driver_grid = grid_with_results.group_by(&:grid)
        points_by_grid = by_driver_grid.map { |grid, grrs|
          avg_pts = grrs.sum { |rr| rr.points.to_f } / grrs.size
          baseline_avg = @grid_points_baseline[grid] || 0
          { grid: grid, avg_pts: avg_pts.round(1), baseline: baseline_avg, count: grrs.size, diff: (avg_pts - baseline_avg).round(1) }
        }.sort_by { |g| g[:grid] }

        # ── Consistency Bands ──
        if clean_rrs.size >= 3
          positions = clean_rrs.map(&:position_order)
          avg_pos_clean = positions.sum.to_f / positions.size
          within_2 = positions.count { |p| (p - avg_pos_clean).abs <= 2 }
          consistency_pct = (within_2.to_f / positions.size * 100).round(1)
          within_5 = positions.count { |p| (p - avg_pos_clean).abs <= 5 }
          wide_pct = (within_5.to_f / positions.size * 100).round(1)
        else
          consistency_pct = nil
          wide_pct = nil
          avg_pos_clean = nil
        end

        # ── Constructor-Adjusted Performance ──
        team_avg = @constructor_baseline[constructor&.id]
        if team_avg && clean_rrs.any?
          driver_avg_pos = clean_rrs.sum(&:position_order).to_f / clean_rrs.size
          car_adjusted = (team_avg - driver_avg_pos).round(2) # positive = better than team avg
        else
          car_adjusted = nil
          driver_avg_pos = nil
        end

        {
          driver: driver,
          constructor: constructor,
          color: color,
          code: code,
          cumulative: cumulative,
          grid_finish_pairs: grid_finish_pairs,
          avg_delta: avg_delta,
          avg_adjusted_delta: avg_adjusted_delta,
          avg_grid: avg_grid,
          clean_races: clean_rrs.size,
          total_races: sorted_rrs.size,
          total_points: rrs.sum(&:points).to_f,
          momentum: momentum,
          points_by_grid: points_by_grid,
          consistency_pct: consistency_pct,
          wide_pct: wide_pct,
          avg_pos_clean: avg_pos_clean&.round(1),
          car_adjusted: car_adjusted,
          driver_avg_pos: driver_avg_pos&.round(1),
          team_avg_pos: team_avg
        }
      end

      @drivers_data.sort_by! { |d| -d[:total_points] }

      # World champions (driver IDs who won a title in the selected range)
      @champion_driver_ids = DriverStanding.where(position: 1, season_end: true)
                                           .joins(:race)
                                           .where(races: { year: @from_year..@to_year })
                                           .pluck(:driver_id)
                                           .uniq
    end
  end
end
