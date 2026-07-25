module HeadToHead
  # Selects the next opponent for the champion in a preference session, ramping
  # through Elo-based bands of the year's grid from worst to best.
  #
  # Bands are fixed-size (5 drivers each) rather than percentiles, so the tiers
  # stay tight even on a 22-driver grid where "bottom quartile" is already 5–6
  # drivers. Middle drivers (between upper- and lower-middle bands) are skipped
  # intentionally — they'd otherwise dominate a middle tier that turned soft.
  class PairPicker
    BAND_SIZE = 5

    TIER_LAYOUTS = {
      # rounds_target => [[tier_name, round_count], ...] in play order
      10 => [["bottom", 3], ["middle", 4], ["top", 3]],
      12 => [["bottom", 3], ["lower_middle", 3], ["upper_middle", 3], ["top", 3]],
    }.freeze

    Pair = Struct.new(:champion, :challenger, :tier, :round_index, keyword_init: true)

    def self.pool_for(year)
      season = Season.find_by(year: year.to_s)
      return [] unless season

      lineup = season.lineup_season || season
      SeasonDriver
        .where(season: lineup, standin: [false, nil])
        .includes(:driver, :constructor)
        .uniq(&:driver_id)
        .map(&:driver)
        .compact
        .reject { |d| d.elo_v2.blank? }
        .sort_by { |d| -d.elo_v2.to_f }
    end

    def initialize(session)
      @session = session
      @year = session.year
      @pool = self.class.pool_for(@year)
    end

    def next_pair
      return nil if @pool.size < 2
      return nil if @session.rounds_played >= @session.rounds_target

      used_ids = matched_driver_ids
      round = @session.rounds_played
      tier = tier_for_round(round)

      # First round: no champion yet — draw both from the bottom tier as warmup.
      # When the tier is too small (small grids in fixtures/tests), widen the pick
      # to the full pool so we can still produce a valid pair.
      if @session.champion_driver_id.nil?
        seed_ids = tier_pool(tier) - used_ids.to_a
        seed_ids = @pool.map(&:id) - used_ids.to_a if seed_ids.size < 2
        return nil if seed_ids.size < 2
        champion_id, challenger_id = seed_ids.sample(2)
        Pair.new(
          champion: Driver.find(champion_id),
          challenger: Driver.find(challenger_id),
          tier: tier, round_index: round,
        )
      else
        champion = Driver.find(@session.champion_driver_id)
        # Never re-fight anyone already seen this session.
        candidates = tier_pool(tier) - used_ids.to_a - [champion.id]
        # Fall back to any remaining fresh driver if the tier is exhausted.
        candidates = @pool.map(&:id) - used_ids.to_a - [champion.id] if candidates.empty?
        return nil if candidates.empty?
        challenger = Driver.find(candidates.sample)
        Pair.new(champion: champion, challenger: challenger, tier: tier, round_index: round)
      end
    end

    def tier_for_round(round_index)
      layout = TIER_LAYOUTS[@session.rounds_target] || default_layout(@session.rounds_target)
      consumed = 0
      layout.each do |name, count|
        consumed += count
        return name if round_index < consumed
      end
      layout.last.first
    end

    private

    def default_layout(total)
      # Fall back to a 3-tier 30/40/30 split for unknown targets.
      bottom = (total * 0.3).round
      middle = (total * 0.4).round
      top = total - bottom - middle
      [["bottom", bottom], ["middle", middle], ["top", top]]
    end

    def matched_driver_ids
      ids = Set.new
      @session.matches.pluck(:winner_driver_id, :loser_driver_id).each do |w, l|
        ids << w
        ids << l
      end
      ids
    end

    def tier_pool(tier)
      return [] if @pool.empty?
      # @pool is sorted best → worst by Elo. Slice fixed 5-driver bands from
      # each end so tier size doesn't balloon on larger grids.
      case tier
      when "top"          then @pool.first(BAND_SIZE).map(&:id)
      when "upper_middle" then (@pool[BAND_SIZE, BAND_SIZE] || []).map(&:id)
      when "lower_middle" then (@pool[[-2 * BAND_SIZE, -@pool.size].max, BAND_SIZE] || []).map(&:id)
      when "middle"
        # Legacy 3-tier layout: everything between the top and bottom bands.
        inner = @pool.size - 2 * BAND_SIZE
        inner > 0 ? @pool[BAND_SIZE, inner].map(&:id) : []
      when "bottom"       then @pool.last(BAND_SIZE).map(&:id)
      else                     []
      end
    end

    def pick_two_from(ids)
      ids.sample(2)
    end
  end
end
