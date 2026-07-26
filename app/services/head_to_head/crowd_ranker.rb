module HeadToHead
  # Opponent-adjusted crowd ranking. Beating a strong opponent scores higher
  # than beating a weak one; losing to a strong opponent hurts less than
  # losing to a weak one. Corrects for the tier-progression bias where
  # mid-tier drivers accumulate easy wins against bottom-tier while top-tier
  # drivers only get a handful of at-bats late in each session.
  #
  # Two passes over the year's matches:
  #   1. raw pct per driver
  #   2. score per match = +opp.pct (win) or -(1 - opp.pct) (loss); mean per driver
  class CrowdRanker
    Row = Struct.new(:driver, :wins, :losses, :total, :pct, :score, keyword_init: true)

    def self.call(year)
      new(year).rows
    end

    def initialize(year)
      @year = year
    end

    def rows
      matches = DriverPreferenceMatch.where(year: @year).pluck(:winner_driver_id, :loser_driver_id)
      return [] if matches.empty?

      wins  = Hash.new(0)
      loses = Hash.new(0)
      matches.each do |w, l|
        wins[w] += 1
        loses[l] += 1
      end

      driver_ids = (wins.keys + loses.keys).uniq
      pct = driver_ids.each_with_object({}) do |id, h|
        total = wins[id] + loses[id]
        h[id] = total.zero? ? 0.0 : wins[id].to_f / total
      end

      contribs = Hash.new { |h, k| h[k] = [] }
      matches.each do |w, l|
        contribs[w] << pct[l]
        contribs[l] << -(1.0 - pct[w])
      end

      drivers = Driver.where(id: driver_ids).index_by(&:id)
      driver_ids.filter_map do |id|
        next unless drivers[id]
        c = contribs[id]
        score = c.empty? ? 0.0 : c.sum / c.size
        total = wins[id] + loses[id]
        Row.new(
          driver:  drivers[id],
          wins:    wins[id],
          losses:  loses[id],
          total:   total,
          pct:     pct[id],
          score:   score,
        )
      end.sort_by { |r| [-r.score, -r.total] }
    end
  end
end
