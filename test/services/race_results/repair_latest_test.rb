require 'test_helper'

class RaceResults::RepairLatestTest < ActiveSupport::TestCase
  setup do
    @race = races(:bahrain_2026)
    @imported_at = Time.zone.parse('2026-03-08 18:00:00')
    @race.race_results.update_all(created_at: @imported_at)
    @race.race_results.includes(:constructor).each do |row|
      row.update!(old_constructor_elo_v2: row.constructor.elo_v2, new_constructor_elo_v2: row.constructor.elo_v2 + 1)
    end
    @rows = @race.race_results.order(:position_order).map { |row| row.attributes.symbolize_keys.slice(*RaceResults::RepairLatest::RESULT_FIELDS) }
    @rows[0][:position] = @rows[0][:position_order] = 2
    @rows[0][:points] = 18.0
    @rows[1][:position] = @rows[1][:position_order] = 1
    @rows[1][:points] = 25.0
    @rows[1][:grid] = 2
    @rows.sort_by! { |row| row[:position_order] }
    FantasyAchievement.delete_all
    FantasyStockAchievement.delete_all
  end

  test 'dry run rolls back results ratings wallets scores cards and snapshots' do
    before = state
    result = RaceResults::RepairLatest.new(race: @race, rows: @rows).call
    assert_equal 'dry_run', result[:status]
    assert_equal drivers(:norris).id, result[:after][:podium].first.first
    assert_equal before, state
  end

  test 'apply repairs only the latest race and is idempotent' do
    original_dates = @race.race_results.order(:id).pluck(:created_at)
    result = RaceResults::RepairLatest.new(race: @race, rows: @rows, dry_run: false, backup_id: 'test-backup').call
    assert_equal 'repaired', result[:status]
    assert_equal drivers(:norris).id, @race.race_results.order(:position_order).first.driver_id
    assert_equal original_dates, @race.race_results.order(:id).pluck(:created_at)
    assert_equal 25.0, DriverStanding.find_by!(race: @race, driver: drivers(:norris)).points
    assert_equal 'unchanged', RaceResults::RepairLatest.new(race: @race, rows: @rows, dry_run: false, backup_id: 'test-backup').call[:status]
  end

  test 'missing backup or a post-import user trade blocks writes' do
    assert_raises(RaceResults::ImportGuard::Rejected) do
      RaceResults::RepairLatest.new(race: @race, rows: @rows, dry_run: false).call
    end
    FantasyStockTransaction.create!(fantasy_stock_portfolio: fantasy_stock_portfolios(:codex_stock_2026),
      race: @race, driver: drivers(:norris), kind: 'buy', amount: -20, created_at: @imported_at + 1.minute)
    before = state
    assert_raises(RaceResults::ImportGuard::Rejected) { RaceResults::RepairLatest.new(race: @race, rows: @rows).call }
    assert_equal before, state
  end

  test 'repairing an older race with downstream results is refused' do
    RaceResult.create!(race: races(:melbourne_2026), driver: drivers(:norris), constructor: constructors(:mclaren),
                       status: statuses(:finished), position: 1, position_order: 1, points: 25)
    assert_raises(RaceResults::ImportGuard::Rejected) { RaceResults::RepairLatest.new(race: @race, rows: @rows).call }
  end

  test 'valid winner card keeps upgrade luck but loses a false upset tier' do
    # Norris was falsely credited with a win from P19. The corrected winner
    # remains Norris, but from P2; a non-upgraded platinum becomes gold.
    @rows.each { |row| row[:position] = row[:position_order] = (row[:driver_id] == drivers(:norris).id ? 1 : row[:position_order]) }
    @race.race_results.find_by!(driver: drivers(:norris)).update!(position: 1, position_order: 1, grid: 19)
    card = DriverCard.create!(user: users(:codex), driver: drivers(:norris), race: @race,
      predicted_position: 1, actual_position: 1, tier: 'platinum', earned_at: @imported_at)
    RaceResults::RepairLatest.new(race: @race, rows: @rows, dry_run: false, backup_id: 'test-backup').call
    assert_equal 'gold', card.reload.tier
    assert_equal @imported_at, card.earned_at
  end

  private

  def state
    [RaceResult, Driver, Constructor, DriverStanding, DriverBadge, DriverCard, RacePick,
     FantasyPortfolio, FantasyStockPortfolio, FantasyStockHolding, FantasyStockTransaction,
     FantasySnapshot, FantasyStockSnapshot, StockPriceSnapshot, FantasyAchievement, FantasyStockAchievement]
      .to_h { |model| [model.name, model.order(:id).map(&:attributes)] }
  end
end
