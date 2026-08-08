module Constructors
  class PairingCalculator
    MIN_RACES = 5
    LIMIT = 50
    SINCE_YEAR = "1990".freeze

    def call
      grouped = SeasonDriver.where(standin: [false, nil])
                   .joins(:season).where("seasons.year >= ?", SINCE_YEAR)
                   .includes(:driver, :season, :constructor)
                   .group_by { |sd| [sd.season_id, sd.constructor_id] }

      pairing_driver_ids = grouped.values.flat_map { |sds| sds.map(&:driver_id) }.uniq
      pairing_season_ids = grouped.keys.map(&:first).uniq
      all_results = RaceResult.where(driver_id: pairing_driver_ids)
                              .joins(:race).where(races: { season_id: pairing_season_ids })
                              .index_by { |rr| [rr.race_id, rr.driver_id] }
      races_by_season = Race.where(season_id: pairing_season_ids)
                            .joins(:race_results).distinct.group_by(&:season_id)

      seen_pairs = Set.new
      pairings = []

      grouped.each do |(_season_id, _constructor_id), sds|
        drivers = sds.map(&:driver).uniq(&:id)
        next if drivers.size < 2

        drivers.combination(2).each do |d1, d2|
          pair_key = [d1.id, d2.id].sort
          next if seen_pairs.include?(pair_key)
          seen_pairs << pair_key

          shared = grouped.select do |(_sid, _cid), group_sds|
            ids = group_sds.map(&:driver_id)
            ids.include?(d1.id) && ids.include?(d2.id)
          end

          stats = compute_stats(shared, all_results, races_by_season, d1, d2)
          next if stats[:races_together] < MIN_RACES

          pairings << {
            driver1: d1,
            driver2: d2,
            constructors: shared.map { |(_sid, _cid), g| g.first.constructor }.uniq(&:id),
            seasons_together: shared.map { |(_sid, _cid), g| g.first.season }.uniq(&:id).sort_by(&:year),
            races_together: stats[:races_together],
            wins: stats[:wins],
            win_pct: percent(stats[:wins], stats[:races_together]),
            one_two_finishes: stats[:one_two_finishes],
            one_two_pct: percent(stats[:one_two_finishes], stats[:races_together])
          }
        end
      end

      pairings.sort_by! { |p| [-p[:one_two_pct], -p[:win_pct], -p[:races_together]] }
      pairings.first(LIMIT)
    end

    private

    def compute_stats(shared, all_results, races_by_season, d1, d2)
      races_together = 0
      wins = 0
      one_two = 0

      shared.each do |(sid, _cid), _|
        (races_by_season[sid] || []).each do |race|
          rr1 = all_results[[race.id, d1.id]]
          rr2 = all_results[[race.id, d2.id]]
          next unless rr1 && rr2

          races_together += 1
          p1 = rr1.position_order
          p2 = rr2.position_order
          wins += 1 if p1 == 1 || p2 == 1
          one_two += 1 if p1 && p2 && [p1, p2].sort == [1, 2]
        end
      end

      { races_together: races_together, wins: wins, one_two_finishes: one_two }
    end

    def percent(count, total)
      (count.to_f / total * 100).round(1)
    end
  end
end
