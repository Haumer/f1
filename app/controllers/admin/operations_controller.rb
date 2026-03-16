module Admin
  class OperationsController < BaseController
    ALLOWED_OPERATIONS = %w[
      sync_season full_data_sync fetch_wikipedia_images
      elo_v2_simulate backfill_careers update_active_drivers compute_badges
      recalc_net_demand resnap_portfolios recalc_dividends
      verify_cash fix_collateral replay_transactions
    ].freeze

    def index
    end

    def create
      op = params[:operation]
      if op.in?(ALLOWED_OPERATIONS)
        send(op)
      else
        redirect_to admin_operations_path, alert: "Unknown operation."
      end
    end

    private

    def sync_season
      year = params[:year].presence || Date.current.year
      PostRaceSyncJob.perform_later(year: year.to_i)
      redirect_to admin_operations_path, notice: "Season #{year} sync job enqueued."
    end

    def elo_v2_simulate
      EloSimulateJob.perform_later
      redirect_to admin_operations_path, notice: "Elo V2 simulation job enqueued."
    end

    def backfill_careers
      BackfillCareersJob.perform_later
      redirect_to admin_operations_path, notice: "Career stats backfill job enqueued."
    end

    def update_active_drivers
      UpdateActiveDrivers.update_season
      redirect_to admin_operations_path, notice: "Active drivers updated."
    end

    def compute_badges
      ComputeBadgesJob.perform_later
      redirect_to admin_operations_path, notice: "Badge computation job enqueued."
    end

    def full_data_sync
      start_year = (params[:start_year].presence || 1950).to_i
      end_year = (params[:end_year].presence || Date.current.year).to_i
      FullDataSyncJob.perform_later(start_year: start_year, end_year: end_year)
      redirect_to admin_operations_path, notice: "Full data sync job enqueued (#{start_year}-#{end_year}). This will take several minutes."
    end

    def fetch_wikipedia_images
      count = FetchWikipediaImages.fetch_all
      redirect_to admin_operations_path, notice: "Fetched #{count} Wikipedia images."
    end

    def recalc_net_demand
      season = Season.sorted_by_year.first
      SeasonDriver.where(season: season).update_all(net_demand: 0)
      holdings = FantasyStockHolding.joins(:fantasy_stock_portfolio)
        .where(fantasy_stock_portfolios: { season_id: season.id }, active: true)
      count = 0
      holdings.group_by(&:driver_id).each do |driver_id, hs|
        longs = hs.select(&:long?).sum(&:quantity)
        shorts = hs.select(&:short?).sum(&:quantity)
        sd = SeasonDriver.find_by(driver_id: driver_id, season_id: season.id)
        next unless sd
        sd.update!(net_demand: longs - shorts)
        count += 1
      end
      redirect_to admin_operations_path, notice: "Recalculated net_demand for #{count} drivers."
    end

    def resnap_portfolios
      race = Race.find(params[:race_id])
      Fantasy::SnapshotPortfolios.new(race: race).call
      Fantasy::Stock::SettleRace.new(race: race).call
      redirect_to admin_operations_path, notice: "Re-snapshotted portfolios for #{race.circuit.name} (R#{race.round})."
    end

    def verify_cash
      season = Season.sorted_by_year.first
      issues = []
      FantasyPortfolio.where(season: season).includes(:user).each do |p|
        sp = FantasyStockPortfolio.find_by(user_id: p.user_id, season_id: season.id)
        next unless sp
        total_starting = Fantasy::CreatePortfolio::STARTING_CAPITAL
        total_accounted = p.cash + sp.positions_value
        diff = (total_accounted - total_starting).round(1)
        issues << "#{p.user.username}: starting=#{total_starting.round(0)} current=#{total_accounted.round(0)} diff=#{diff}" if diff.abs > 50
      end
      msg = issues.any? ? "Issues found: #{issues.join('; ')}" : "All portfolios consistent."
      redirect_to admin_operations_path, notice: msg
    end

    def fix_collateral
      season = Season.sorted_by_year.first
      count = 0
      FantasyStockHolding.joins(:fantasy_stock_portfolio)
        .where(fantasy_stock_portfolios: { season_id: season.id }, active: true, direction: "short")
        .includes(:driver, :fantasy_stock_portfolio).each do |h|
        price = h.fantasy_stock_portfolio.share_price(h.driver)
        correct = price * h.quantity * FantasyStockPortfolio::COLLATERAL_RATIO
        next if (h.collateral - correct).abs < 0.01
        h.update!(collateral: correct)
        count += 1
      end
      redirect_to admin_operations_path, notice: "Fixed collateral for #{count} short positions (#{(FantasyStockPortfolio::COLLATERAL_RATIO * 100).round(0)}% ratio)."
    end

    def replay_transactions
      season = Season.sorted_by_year.first
      dry_run = params[:dry_run] == "1"
      results = Fantasy::ReplayTransactions.new(season: season, dry_run: dry_run).call
      summary = results.map { |r| "#{r[:user]}: #{r[:old_cash]}→#{r[:new_cash]} (#{r[:diff] >= 0 ? '+' : ''}#{r[:diff]})" }.join("; ")
      prefix = dry_run ? "[DRY RUN] " : ""
      redirect_to admin_operations_path, notice: "#{prefix}Replayed transactions: #{summary}"
    end

    def recalc_dividends
      season = Season.sorted_by_year.first
      races = Race.where(season: season).where.not(date: nil).where("date < ?", Date.current).order(:round)
      portfolio_ids = FantasyStockPortfolio.where(season: season).pluck(:id)
      race_ids = races.pluck(:id)

      old_divs = FantasyStockTransaction.where(fantasy_stock_portfolio_id: portfolio_ids, race_id: race_ids, kind: "dividend")
      reversed_cash = Hash.new(0)
      old_divs.find_each { |t| reversed_cash[t.fantasy_stock_portfolio_id] += t.amount }
      deleted = old_divs.delete_all

      reversed_cash.each do |portfolio_id, amount|
        sp = FantasyStockPortfolio.find(portfolio_id)
        sp.wallet&.update!(cash: sp.wallet.cash - amount)
      end

      elo_ranks = Driver.where(active: true).order(elo_v2: :desc).pluck(:id)
                    .each_with_index.to_h { |id, idx| [id, idx + 1] }
      portfolios = FantasyStockPortfolio.where(season: season).includes(holdings: :driver)

      races.each do |race|
        results_by_driver = RaceResult.where(race: race).index_by(&:driver_id)
        settle = Fantasy::Stock::SettleRace.new(race: race)
        settle.instance_variable_set(:@elo_ranks, elo_ranks)

        portfolios.each do |portfolio|
          ActiveRecord::Base.transaction do
            portfolio.lock!
            portfolio.wallet&.lock!
            settle.send(:pay_dividends, portfolio, results_by_driver)
          end
        end
      end
      redirect_to admin_operations_path, notice: "Recalculated dividends for #{races.count} races (deleted #{deleted} old transactions)."
    end

  end
end
