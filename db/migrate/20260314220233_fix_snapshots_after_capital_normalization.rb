class FixSnapshotsAfterCapitalNormalization < ActiveRecord::Migration[7.0]
  def up
    target = 9450.0

    # For each roster portfolio, compute how much capital was originally given
    # (sum of starting_capital transactions) and adjust snapshots by the shortfall.
    execute <<-SQL
      UPDATE fantasy_snapshots fs
      SET value = fs.value + (#{target} - orig.total_given),
          cash  = fs.cash  + (#{target} - orig.total_given)
      FROM (
        SELECT fantasy_portfolio_id, COALESCE(SUM(amount), 0) AS total_given
        FROM fantasy_transactions
        WHERE kind = 'starting_capital'
        GROUP BY fantasy_portfolio_id
      ) orig
      WHERE fs.fantasy_portfolio_id = orig.fantasy_portfolio_id
        AND orig.total_given != #{target}
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
