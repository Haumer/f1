module Homepage
  class LeaderboardPreview
    Result = Struct.new(:entries, :self_entry, :max_net, keyword_init: true)

    def initialize(season:, user: nil, limit: 5)
      @season = season
      @user = user
      @limit = limit
    end

    def call
      ranked = Fantasy::Leaderboard.new(season: @season).call
        .map.with_index(1) do |entry, rank|
          entry.merge(user: entry[:portfolio].user, rank: rank)
        end

      return Result.new(entries: [], self_entry: nil, max_net: 0) if ranked.empty?

      top = ranked.first(@limit)
      max_net = [top.first[:net], 1].max

      Result.new(
        entries: enrich_top_entries(top, max_net),
        self_entry: build_self_entry(ranked, top, max_net),
        max_net: max_net
      )
    end

    private

    def enrich_top_entries(entries, max_net)
      transactions = latest_transactions(entries)

      entries.map do |entry|
        entry.merge(
          last_action: transactions[entry[:stock_portfolio_id]],
          gap_percent: gap_percent(entry[:net], max_net)
        )
      end
    end

    def latest_transactions(entries)
      portfolio_ids = entries.filter_map { |entry| entry[:stock_portfolio_id] }
      return {} if portfolio_ids.empty?

      FantasyStockTransaction
        .where(fantasy_stock_portfolio_id: portfolio_ids)
        .select("DISTINCT ON (fantasy_stock_portfolio_id) *")
        .order("fantasy_stock_portfolio_id, created_at DESC")
        .includes(:driver)
        .index_by(&:fantasy_stock_portfolio_id)
    end

    def build_self_entry(ranked, top, max_net)
      return unless @user
      return if top.any? { |entry| entry[:portfolio].user_id == @user.id }

      entry = ranked.find { |candidate| candidate[:portfolio].user_id == @user.id }
      entry&.merge(last_action: nil, gap_percent: gap_percent(entry[:net], max_net))
    end

    def gap_percent(net, max_net)
      (net.to_f / max_net * 100).clamp(0, 100)
    end
  end
end
