module Fantasy
  module Stock
    class CheckAchievements
      def initialize(portfolio:, race: nil)
        @portfolio = portfolio
        @race = race
      end

      def call
        earned = []
        earned << award(:first_stock_trade) if check_trade_count(1)
        earned << award(:five_stock_trades) if check_trade_count(5)
        earned << award(:ten_stock_trades) if check_trade_count(10)
        earned << award(:first_long) if check_has_direction("long")
        earned << award(:first_short) if check_has_direction("short")
        earned << award(:max_positions) if check_max_positions
        earned << award(:first_stock_profit) if check_profit(0)
        earned << award(:stock_profit_500) if check_profit(500)
        earned << award(:stock_profit_1000) if check_profit(1000)
        earned << award(:profitable_short) if check_profitable_short
        earned << award(:first_dividend) if check_dividend
        earned << award(:stock_top_3) if check_leaderboard_rank(3)
        earned << award(:stock_top_1) if check_leaderboard_rank(1)
        earned.compact
      end

      private

      def award(key)
        return nil if @portfolio.has_achievement?(key)

        definition = FantasyStockAchievement::DEFINITIONS[key]
        return nil unless definition

        @portfolio.achievements.create!(
          key: key.to_s,
          tier: definition[:tier],
          earned_at: Time.current
        )
      rescue ActiveRecord::RecordNotUnique
        nil
      end

      def check_trade_count(n)
        @portfolio.transactions.where(kind: %w[buy sell short_open short_close]).count >= n
      end

      def check_has_direction(direction)
        @portfolio.holdings.where(direction: direction).exists?
      end

      def check_max_positions
        @portfolio.active_holdings.count >= FantasyStockPortfolio::MAX_POSITIONS
      end

      def check_profit(threshold)
        @portfolio.profit_loss > threshold
      end

      def check_profitable_short
        @portfolio.holdings.where(direction: "short", active: false).any? do |h|
          # Closed short: profit if closed at lower price than entry
          h.gain_loss > 0
        end
      end

      def check_dividend
        @portfolio.transactions.where(kind: "dividend").exists?
      end

      def check_leaderboard_rank(max_rank)
        latest_snapshot = @portfolio.snapshots.order(created_at: :desc).first
        return false unless latest_snapshot&.rank
        latest_snapshot.rank <= max_rank
      end
    end
  end
end
