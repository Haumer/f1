class NormalizeStartingCapital < ActiveRecord::Migration[7.0]
  def up
    target = 9450.0

    # Top up each roster portfolio's cash by the shortfall and set starting_capital to 9450
    execute <<-SQL
      UPDATE fantasy_portfolios
      SET cash = cash + (#{target} - starting_capital),
          starting_capital = #{target}
      WHERE starting_capital != #{target}
    SQL

    # Ensure stock portfolios have starting_capital = 0 (all capital lives in roster)
    execute <<-SQL
      UPDATE fantasy_stock_portfolios
      SET starting_capital = 0
      WHERE starting_capital != 0
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
