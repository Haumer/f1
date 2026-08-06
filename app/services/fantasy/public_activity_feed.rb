module Fantasy
  # Global (all users) activity stream for the homepage ticker — pulls the
  # highest-signal recent events across users with a public profile.
  #
  # Read-only, cache-friendly: the entries are plain hashes so they survive
  # Rails.cache serialization without dragging AR objects along. The caller
  # is responsible for rendering; this service just picks and orders.
  class PublicActivityFeed
    KIND_LABELS = {
      "buy"                 => "bought",
      "sell"                => "sold",
      "short_open"          => "shorted",
      "short_close"         => "closed short on",
      "card_earned"         => "earned a card for",
      "card_combined"       => "combined into",
      "achievement_earned"  => "unlocked"
    }.freeze

    TRADE_KINDS = %w[buy sell short_open short_close].freeze
    CACHE_TTL = 60.seconds

    def self.recent(season:, limit: 20)
      Rails.cache.fetch(cache_key(season, limit), expires_in: CACHE_TTL) do
        new(season: season, limit: limit).entries
      end
    end

    def self.cache_key(season, limit)
      "fantasy/public_activity/v1/season-#{season.id}/limit-#{limit}"
    end

    def initialize(season:, limit: 20)
      @season = season
      @limit = limit
    end

    def entries
      (trade_entries + card_entries)
        .sort_by { |e| -e[:occurred_at].to_i }
        .first(@limit)
    end

    private

    def public_user_ids
      @public_user_ids ||= User.where(public_profile: true).pluck(:id).to_set
    end

    def trade_entries
      # Two-stage: pull a wider batch newest-first, then filter by public
      # profile in Ruby — avoids a join and keeps the query on the fast
      # (portfolio_id, created_at) index.
      FantasyStockTransaction
        .joins(:fantasy_stock_portfolio)
        .where(kind: TRADE_KINDS)
        .where(fantasy_stock_portfolios: { season_id: @season.id })
        .where("fantasy_stock_transactions.created_at > ?", 14.days.ago)
        .order(created_at: :desc)
        .limit(@limit * 3)
        .includes(:driver, fantasy_stock_portfolio: :user)
        .filter_map { |txn|
          user = txn.fantasy_stock_portfolio&.user
          next unless user && public_user_ids.include?(user.id)
          {
            occurred_at: txn.created_at,
            kind: txn.kind,
            verb: KIND_LABELS[txn.kind] || txn.kind,
            username: user.username,
            driver_name: txn.driver&.surname,
            driver_id: txn.driver_id,
            amount: txn.amount
          }
        }
    end

    def card_entries
      DriverCard.joins(:race)
                .where(races: { season_id: @season.id })
                .where("driver_cards.earned_at > ?", 14.days.ago)
                .order(earned_at: :desc)
                .limit(@limit * 2)
                .includes(:driver, :user)
                .filter_map { |c|
                  next unless c.user && public_user_ids.include?(c.user_id)
                  combined = c.combined?
                  {
                    occurred_at: c.earned_at,
                    kind: combined ? "card_combined" : "card_earned",
                    verb: KIND_LABELS[combined ? "card_combined" : "card_earned"],
                    username: c.user.username,
                    driver_name: c.driver&.surname,
                    driver_id: c.driver_id,
                    tier: c.tier
                  }
                }
    end
  end
end
