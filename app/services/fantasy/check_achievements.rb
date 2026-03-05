module Fantasy
  class CheckAchievements
    def initialize(portfolio:, race: nil)
      @portfolio = portfolio
      @race = race
    end

    def call
      earned = []
      earned << award(:early_adopter) if check_early_adopter
      earned << award(:first_trade) if check_trade_count(1)
      earned << award(:five_trades) if check_trade_count(5)
      earned << award(:ten_trades) if check_trade_count(10)
      earned << award(:first_profit) if check_profit(0)
      earned << award(:profit_500) if check_profit(500)
      earned << award(:profit_1000) if check_profit(1000)
      earned << award(:all_time_high) if check_all_time_high
      earned << award(:streak_3) if check_streak(3)
      earned << award(:second_team) if check_teams(2)
      earned << award(:third_team) if check_teams(3)

      if @race
        earned << award(:driver_won) if check_driver_position(1)
        earned << award(:driver_podium) if check_driver_position(3)
        earned << award(:driver_elo_surge) if check_driver_elo_surge(40)
      end

      # Leaderboard checks
      earned << award(:top_3) if check_leaderboard_rank(3)
      earned << award(:top_1) if check_leaderboard_rank(1)

      earned.compact
    end

    private

    def award(key)
      return nil if @portfolio.has_achievement?(key)

      definition = FantasyAchievement::DEFINITIONS[key]
      return nil unless definition

      @portfolio.achievements.create!(
        key: key.to_s,
        tier: definition[:tier],
        earned_at: Time.current
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def check_early_adopter
      first_race = @portfolio.season.races.order(:date).first
      return false unless first_race
      @portfolio.created_at < first_race.date.beginning_of_day
    end

    def check_trade_count(n)
      @portfolio.transactions.where(kind: %w[buy sell]).count >= n
    end

    def check_profit(threshold)
      @portfolio.profit_loss > threshold
    end

    def check_all_time_high
      snapshots = @portfolio.snapshots.order(:created_at).pluck(:value)
      return false if snapshots.size < 2
      snapshots.last == snapshots.max
    end

    def check_streak(n)
      values = @portfolio.snapshots.order(:created_at).pluck(:value)
      return false if values.size < n + 1

      # Check if last n changes were all positive
      changes = values.each_cons(2).map { |a, b| b - a }
      changes.last(n).all? { |c| c > 0 }
    end

    def check_teams(n)
      @portfolio.teams_owned >= n
    end

    def check_driver_position(max_position)
      return false unless @race
      driver_ids = @portfolio.active_roster_entries.pluck(:driver_id)
      RaceResult.where(race: @race, driver_id: driver_ids, position_order: 1..max_position).exists?
    end

    def check_driver_elo_surge(threshold)
      return false unless @race
      driver_ids = @portfolio.active_roster_entries.pluck(:driver_id)
      RaceResult.where(race: @race, driver_id: driver_ids).any? do |rr|
        diff = (rr.new_elo_v2 || 0) - (rr.old_elo_v2 || 0)
        diff >= threshold
      end
    end

    def check_leaderboard_rank(max_rank)
      latest_snapshot = @portfolio.snapshots.order(created_at: :desc).first
      return false unless latest_snapshot&.rank
      latest_snapshot.rank <= max_rank
    end
  end
end
