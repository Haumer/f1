require 'digest'

module RaceResults
  # Explicit operator-only repair. Never called by a page or background sync.
  # A dry run executes the same transaction and rolls it back. An apply requires
  # an externally verified backup; the task additionally requires the race ID.
  class RepairLatest
    SETTLEMENT_KINDS = %w[dividend borrow_fee pick_reward].freeze
    TRADE_KINDS = %w[buy sell short_open short_close].freeze
    RESULT_FIELDS = %i[driver_id constructor_id status_id position position_order points laps time grid number
                       milliseconds fastest_lap fastest_lap_time fastest_lap_speed].freeze

    def initialize(race:, rows:, dry_run: true, backup_id: nil)
      @race, @rows, @dry_run, @backup_id = race, rows, dry_run, backup_id
    end

    def call
      raise ImportGuard::Rejected, 'A verified backup is required to apply' if !@dry_run && @backup_id.blank?
      report = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        @race.lock!
        @existing = @race.race_results.reload.order(:id).to_a
        if signature(@existing.map { |r| r.attributes.symbolize_keys }) == signature(@rows)
          report = { status: 'unchanged', race_id: @race.id }
          next
        end
        validate!

        report = { status: @dry_run ? 'dry_run' : 'repaired', race_id: @race.id, backup_id: @backup_id,
                   before: summary, source_digest: Digest::SHA256.hexdigest(signature(@rows).to_json) }
        old_cards = DriverCard.where(race: @race).to_a
        timestamp_models = [FantasyStockTransaction, FantasySnapshot, FantasyStockSnapshot, StockPriceSnapshot]
        timestamps = timestamp_models.to_h { |model| [model, model.where(race: @race).to_a.to_h { |row| [timestamp_key(row), row.created_at] }] }
        original_settlement_at = FantasyStockTransaction.where(race: @race, kind: SETTLEMENT_KINDS).minimum(:created_at) || @imported_at
        wallets = FantasyPortfolio.where(season_id: @race.season_id).lock.to_a
        FantasyStockPortfolio.where(season_id: @race.season_id).lock.load
        validate! # Recheck trading after acquiring the same locks used by trades.
        preserve_trades = trade_fingerprint

        restore_ratings
        @rows.each do |row|
          result = @existing.find { |existing| existing.driver_id == row[:driver_id] }
          result.update!(row.slice(*RESULT_FIELDS).merge(old_elo_v2: nil, new_elo_v2: nil,
                          old_constructor_elo_v2: nil, new_constructor_elo_v2: nil))
        end
        @race.reload
        EloRatingV2.process_race(@race)
        ConstructorEloV2.process_race(@race)
        ComputeSeasonStandings.new(race: @race).call
        @race.race_results.includes(:driver).each { |result| UpdateDriverCareer.new(driver: result.driver).update }

        FantasyStockTransaction.where(race: @race, kind: SETTLEMENT_KINDS).delete_all
        StockPriceSnapshot.where(race: @race).delete_all
        wallets.each do |wallet|
          stock = FantasyStockPortfolio.find_by(user_id: wallet.user_id, season_id: @race.season_id)
          wallet.update!(cash: wallet.transactions.sum(:amount) + (stock&.transactions&.sum(:amount) || 0))
        end
        repair_existing_cards(old_cards)
        Fantasy::Stock::SettleRace.new(race: @race).call if Setting.fantasy_stock_market?
        Fantasy::ScoreRacePicks.new(race: @race, card_rng: Random.new(@race.id)).call
        Fantasy::SnapshotPortfolios.new(race: @race).call

        FantasyStockPortfolio.where(season_id: @race.season_id).find_each do |portfolio|
          Fantasy::Stock::CheckAchievements.new(portfolio: portfolio, race: @race).call
        end
        wallets.each { |wallet| Fantasy::CheckAchievements.new(portfolio: wallet, race: @race).call }

        timestamp_models.each do |model|
          model.where(race: @race).find_each do |row|
            next if row.is_a?(FantasyStockTransaction) && !row.kind.in?(SETTLEMENT_KINDS)
            row.update_columns(created_at: timestamps[model][timestamp_key(row)] || original_settlement_at)
          end
        end
        DriverCard.where(race: @race).where.not(id: old_cards.map(&:id)).update_all(earned_at: original_settlement_at, created_at: original_settlement_at)
        @existing.map(&:driver_id).each do |driver_id|
          driver = Driver.includes(race_results: [:status, :constructor, { race: :circuit }], driver_standings: { race: :season }).find(driver_id)
          DriverBadges.new(driver: driver).persist!
        end
        DriverBadges.assign_tiers!
        raise ImportGuard::Rejected, 'Repair changed a user trade' unless preserve_trades == trade_fingerprint
        report[:after] = summary
        raise ActiveRecord::Rollback if @dry_run
      end
      report
    end

    private

    def validate!
      raise ImportGuard::Rejected, 'Only a completed latest race can be repaired' if @existing.empty? ||
        Race.joins(:race_results).where('date > ?', @race.date).exists?
      raise ImportGuard::Rejected, 'Sprint weekends require a separate repair audit' if @race.sprint?
      raise ImportGuard::Rejected, 'Replacement must cover the exact stored field' unless @rows.map { |r| r[:driver_id] }.sort == @existing.map(&:driver_id).sort
      ImportGuard.new(race: @race).validate_rows!(@rows)
      @imported_at = @existing.map(&:created_at).min
      raise ImportGuard::Rejected, 'User trades after import require a pricing audit' if trades.where('fantasy_stock_transactions.created_at >= ?', @imported_at).exists?
      raise ImportGuard::Rejected, 'Liquidations require a holdings/demand repair' if FantasyStockTransaction.where(race: @race, kind: 'liquidation').exists?
      raise ImportGuard::Rejected, 'Combined cards require a separate ownership audit' if DriverCard.where('? = ANY(combined_from_race_ids)', @race.id).exists?
      [FantasyAchievement, FantasyStockAchievement].each do |model|
        raise ImportGuard::Rejected, 'New achievements require an award audit' if model.where('earned_at >= ?', @imported_at).exists?
      end
    end

    def restore_ratings
      [[Driver, :driver_id, :old_elo_v2, :new_elo_v2],
       [Constructor, :constructor_id, :old_constructor_elo_v2, :new_constructor_elo_v2]].each do |model, foreign_key, old_column, new_column|
        @existing.group_by { |row| row.public_send(foreign_key) }.each do |id, results|
          old_values = results.map { |row| row.public_send(old_column) }.uniq
          raise ImportGuard::Rejected, 'Missing or inconsistent pre-race Elo' unless old_values.one? && old_values.first&.finite?
          peak = RaceResult.joins(:race).where(foreign_key => id).where('races.date < ?', @race.date).maximum(new_column)
          model.find(id).update!(elo_v2: old_values.first, peak_elo_v2: [peak || old_values.first, old_values.first].max)
        end
      end
    end

    def repair_existing_cards(cards)
      cards.each do |card|
        correct = @rows.find { |row| row[:driver_id] == card.driver_id }
        if correct[:position_order] != card.predicted_position
          card.destroy!
          next
        end
        old = @existing.find { |row| row.driver_id == card.driver_id }
        # Preserve the original lucky upgrade, not the false "won from P19"
        # upset category. Existing legitimate cards keep their IDs/earned_at.
        base = DriverCards::ResolveTier.call(predicted: card.predicted_position, actual: card.actual_position,
                                             grid: @original_grids.fetch(old.driver_id), rng: Struct.new(:rand).new(1.0))
        bumped = card.tier != base
        tier = DriverCards::ResolveTier.call(predicted: card.predicted_position, actual: correct[:position_order],
                                             grid: correct[:grid], rng: Struct.new(:rand).new(bumped ? 0.0 : 1.0))
        driver = card.driver.reload
        card.update!(tier: tier, snapshot_elo: driver.elo_v2, snapshot_wins: driver.wins, snapshot_podiums: driver.podiums)
      end
    end

    def signature(rows)
      rows.map { |row| row.slice(*RESULT_FIELDS).map { |key, value| [key.to_s, value.to_s] }.sort }.sort_by(&:to_s)
    end

    def summary
      @original_grids ||= @existing.to_h { |row| [row.driver_id, row.grid] }
      { results: @race.race_results.count,
        podium: @race.race_results.order(:position_order).first(3).map { |row| [row.driver_id, row.position_order, row.grid] },
        transactions: FantasyStockTransaction.where(race: @race).group(:kind).count,
        settlement_amount: FantasyStockTransaction.where(race: @race, kind: SETTLEMENT_KINDS).sum(:amount).round(2),
        wallet_cash: FantasyPortfolio.where(season_id: @race.season_id).sum(:cash).round(2),
        pick_scores: RacePick.where(race: @race).pluck(:score), cards: DriverCard.where(race: @race).count }
    end

    def timestamp_key(row)
      [row.try(:fantasy_portfolio_id), row.try(:fantasy_stock_portfolio_id), row.try(:driver_id), row.try(:kind)]
    end

    def trades
      FantasyStockTransaction.joins(:fantasy_stock_portfolio).where(fantasy_stock_portfolios: { season_id: @race.season_id }, kind: TRADE_KINDS)
    end

    def trade_fingerprint
      Digest::SHA256.hexdigest(trades.order(:id).map(&:attributes).to_json)
    end
  end
end
