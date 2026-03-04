class StatsController < ApplicationController
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
        # Only consider drivers with 20+ race results
        driver_ids = RaceResult.group(:driver_id)
                                .having("COUNT(*) >= 20")
                                .pluck(:driver_id)

        drivers = Driver.where(id: driver_ids).includes(:countries)

        risers = drivers.filter_map do |driver|
            results = driver.race_results.joins(:race).order("races.date ASC").limit(20)
                             .pluck(old_elo_col, new_elo_col)
            next if results.empty?
            first_old = results.first[0]
            last_new = results.last[1]
            next unless first_old && last_new
            { driver: driver, rise: (last_new - first_old).round, start_elo: first_old.round, end_elo: last_new.round }
        end

        risers.sort_by { |r| -r[:rise] }.first(10)
    end
end
