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
    # Minimum picks a driver needs before they can appear on the podium.
    # Below this, they still show in the table (with a "New" tag in the view)
    # but a lucky single-pick doesn't dominate the top-3.
    PODIUM_MIN_TOTAL = 3

    Row = Struct.new(:driver, :wins, :losses, :total, :pct, :score, :crowd_score, :display_rank, keyword_init: true) do
      def podium_eligible?
        total >= PODIUM_MIN_TOTAL
      end
    end

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
      all_rows = driver_ids.filter_map do |id|
        next unless drivers[id]
        c = contribs[id]
        score = c.empty? ? 0.0 : c.sum / c.size
        total = wins[id] + loses[id]
        Row.new(
          driver:      drivers[id],
          wins:        wins[id],
          losses:      loses[id],
          total:       total,
          pct:         pct[id],
          score:       score,
          crowd_score: ((score + 1.0) * 50.0).round,
        )
      end.sort_by { |r| [-r.score, -r.total] }

      # Eligible drivers first (get 1..N ranks), ineligible drivers appended at
      # the end (no rank — the view renders "—" for them). Keeps the podium
      # numbering (1/2/3) in sync with the table numbering.
      eligible, ineligible = all_rows.partition(&:podium_eligible?)
      eligible.each_with_index { |r, i| r.display_rank = i + 1 }
      eligible + ineligible
    end
  end
end
