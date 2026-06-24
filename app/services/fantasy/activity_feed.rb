module Fantasy
  # Unified, chronological stream of everything a user "did" this season:
  # credit movement (stock trades, race payouts, dividends, bonuses) AND card
  # events (earning a card from picks, combining cards into a higher tier).
  #
  # Read-only presenter — no DB changes. Pulls from FantasyStockTransaction +
  # DriverCard and yields a uniform Entry struct so the view doesn't have to
  # case-switch on model type.
  class ActivityFeed
    # Single row in the feed. credits_delta, card, and achievement are
    # independently nullable: a stock buy sets credits_delta only; a card grant
    # sets card only; an achievement unlock sets achievement only. A future
    # card-for-credits trade would set credits_delta + card together.
    #
    # `achievement` is a small hash { tier:, name:, description:, icon: } so the
    # view doesn't have to know the underlying model class.
    Entry = Struct.new(
      :occurred_at, :kind, :driver, :race,
      :credits_delta, :card, :achievement, :note,
      keyword_init: true
    )

    def self.for_user(user, season:, limit: 50)
      new(user: user, season: season, limit: limit).entries
    end

    def initialize(user:, season:, limit: 50)
      @user = user
      @season = season
      @limit = limit
    end

    def entries
      (credit_entries + card_entries + achievement_entries)
        .sort_by { |e| -e.occurred_at.to_i }
        .first(@limit)
    end

    private

    def credit_entries
      portfolio = @user.fantasy_stock_portfolio_for(@season)
      return [] unless portfolio

      portfolio.transactions
               .includes(:driver, :race)
               .order(created_at: :desc)
               .limit(@limit)
               .map { |t| credit_entry(t) }
    end

    def credit_entry(txn)
      Entry.new(
        occurred_at: txn.created_at,
        kind: txn.kind,
        driver: txn.driver,
        race: txn.race,
        credits_delta: txn.amount,
        card: nil,
        note: txn.note
      )
    end

    def card_entries
      DriverCard.where(user: @user)
                .joins(:race).where(races: { season_id: @season.id })
                .includes(:driver, race: :circuit)
                .order(earned_at: :desc)
                .limit(@limit)
                .map { |c| card_entry(c) }
    end

    def card_entry(card)
      combined = card.combined?
      Entry.new(
        occurred_at: card.earned_at,
        kind: combined ? "card_combined" : "card_earned",
        driver: card.driver,
        race: card.race,
        credits_delta: nil,
        card: card,
        note: combined ? combine_note(card) : nil
      )
    end

    def combine_note(card)
      idx = DriverCard::TIERS.index(card.tier)
      prev = idx && idx > 0 ? DriverCard::TIERS[idx - 1] : nil
      n = card.combined_from_race_ids.size
      prev ? "Combined from #{n} #{prev.capitalize} cards" : "Combined from #{n} cards"
    end

    def achievement_entries
      from_portfolio_achievements + from_stock_achievements
    end

    def from_portfolio_achievements
      portfolio = @user.fantasy_portfolio_for(@season)
      return [] unless portfolio
      portfolio.achievements.map { |a| achievement_entry(a, FantasyAchievement::DEFINITIONS) }
    end

    def from_stock_achievements
      portfolio = @user.fantasy_stock_portfolio_for(@season)
      return [] unless portfolio
      portfolio.achievements.map { |a| achievement_entry(a, FantasyStockAchievement::DEFINITIONS) }
    end

    def achievement_entry(record, definitions)
      defn = definitions[record.key.to_sym] || {}
      Entry.new(
        occurred_at: record.earned_at || record.created_at,
        kind: "achievement_earned",
        driver: nil,
        race: nil,
        credits_delta: nil,
        card: nil,
        achievement: {
          tier: record.tier,
          name: defn[:name] || record.key.to_s.humanize,
          description: defn[:description],
          icon: defn[:icon]
        },
        note: nil
      )
    end
  end
end
