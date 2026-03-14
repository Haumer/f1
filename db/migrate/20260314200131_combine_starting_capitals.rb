class CombineStartingCapitals < ActiveRecord::Migration[7.0]
  def up
    # Merge stock starting_capital into roster starting_capital
    execute <<-SQL
      UPDATE fantasy_portfolios fp
      SET starting_capital = fp.starting_capital + fsp.starting_capital
      FROM fantasy_stock_portfolios fsp
      WHERE fsp.user_id = fp.user_id AND fsp.season_id = fp.season_id
        AND fsp.starting_capital > 0
    SQL

    # Zero out stock starting_capital — it's now part of roster's
    execute <<-SQL
      UPDATE fantasy_stock_portfolios SET starting_capital = 0
      WHERE starting_capital > 0
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
