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
    # Weight applied to a driver's current-season race points when sorting the
    # pool. Ranking = elo_v2 + SEASON_FORM_WEIGHT * season_race_points. Elo
    # stays the base (career signal), form nudges the order so a hot 2026 run
    # moves a driver up a tier without a couple of good races dominating.
    SEASON_FORM_WEIGHT = 4

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
      points_by_driver = RaceResult
        .joins(:race)
        .where(races: { season_id: season.id })
        .group(:driver_id)
        .sum(:points)

      SeasonDriver
        .where(season: lineup, standin: [false, nil])
        .includes(:driver, :constructor)
        .uniq(&:driver_id)
        .map(&:driver)
        .compact
        .reject { |d| d.elo_v2.blank? }
        .sort_by { |d| -(d.elo_v2.to_f + SEASON_FORM_WEIGHT * points_by_driver[d.id].to_f) }
    end

    def initialize(session)
      @session = session
      @year = session.year
      @pool = self.class.pool_for(@year)
      @pool_by_id = @pool.index_by(&:id)
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
        seed_ids = tier_pool(tier) - used_ids
        seed_ids = @pool.map(&:id) - used_ids if seed_ids.size < 2
        return nil if seed_ids.size < 2
        champion_id = seed_ids.sample
        challenger_id = pick_diverse_challenger(seed_ids - [champion_id], [champion_id])
        Pair.new(
          champion: driver_by_id(champion_id),
          challenger: driver_by_id(challenger_id),
          tier: tier, round_index: round,
        )
      else
        champion = driver_by_id(@session.champion_driver_id)
        # Never re-fight anyone already seen this session.
        candidates = tier_pool(tier) - used_ids - [champion.id]
        # Fall back to any remaining fresh driver if the tier is exhausted.
        candidates = @pool.map(&:id) - used_ids - [champion.id] if candidates.empty?
        return nil if candidates.empty?
        challenger_id = pick_diverse_challenger(candidates, used_ids + [champion.id])
        Pair.new(champion: champion, challenger: driver_by_id(challenger_id), tier: tier, round_index: round)
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
      @session.matches.pluck(:winner_driver_id, :loser_driver_id).flatten.uniq
    end

    def driver_by_id(id)
      # Prefer the pool's cached driver (spares a DB roundtrip); fall back to
      # a lookup for the champion carried over from a prior session state.
      @pool_by_id[id] || Driver.find(id)
    end

    # From a list of candidate driver ids, prefer one whose constructor hasn't
    # appeared yet among the "seen" driver ids. Falls back to any candidate if
    # every candidate's team is already represented. Keeps a session tending
    # toward covering every team on the grid.
    def pick_diverse_challenger(candidates, seen_driver_ids)
      return nil if candidates.empty?
      seen_teams = seen_driver_ids.map { |id| constructor_id_by_driver[id] }.compact.to_set
      fresh = candidates.reject { |id| seen_teams.include?(constructor_id_by_driver[id]) }
      (fresh.any? ? fresh : candidates).sample
    end

    def constructor_id_by_driver
      @constructor_id_by_driver ||= begin
        season = Season.find_by(year: @year.to_s)
        return {} unless season
        lineup = season.lineup_season || season
        SeasonDriver
          .where(season: lineup, standin: [false, nil])
          .uniq(&:driver_id)
          .to_h { |sd| [sd.driver_id, sd.constructor_id] }
      end
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

  end
end
