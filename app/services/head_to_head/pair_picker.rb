module HeadToHead
  # Selects the next opponent for the champion in a preference session, ramping
  # through Elo-based tiers of the year's grid: bottom-25% → middle-50% → top-25%.
  #
  # For a fixed 10-round session we split rounds 3 / 4 / 3 across tiers so the
  # last picks always face the top of the grid.
  class PairPicker
    TIER_SPLITS = {
      # rounds_target => [bottom_rounds, middle_rounds, top_rounds]
      10 => [3, 4, 3],
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
      splits = TIER_SPLITS[@session.rounds_target] || default_splits(@session.rounds_target)
      bottom, middle, _top = splits
      if round_index < bottom
        "bottom"
      elsif round_index < bottom + middle
        "middle"
      else
        "top"
      end
    end

    private

    def default_splits(total)
      bottom = (total * 0.3).round
      middle = (total * 0.4).round
      top = total - bottom - middle
      [bottom, middle, top]
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
      size = @pool.size
      # Quartile split: bottom = worst 25%, top = best 25%, middle = the rest.
      # @pool is sorted best → worst by Elo.
      top_cut = (size * 0.25).ceil
      bottom_cut = (size * 0.25).ceil
      case tier
      when "top"    then @pool.first(top_cut).map(&:id)
      when "bottom" then @pool.last(bottom_cut).map(&:id)
      else               @pool[top_cut...(size - bottom_cut)].to_a.map(&:id)
      end
    end

    def pick_two_from(ids)
      ids.sample(2)
    end
  end
end
