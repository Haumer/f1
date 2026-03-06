class CreateFantasyStockAchievements < ActiveRecord::Migration[7.0]
  def change
    create_table :fantasy_stock_achievements do |t|
      t.references :fantasy_stock_portfolio, null: false, foreign_key: true, index: true
      t.string :key
      t.string :tier
      t.datetime :earned_at

      t.timestamps
    end

    add_index :fantasy_stock_achievements,
              [:fantasy_stock_portfolio_id, :key],
              unique: true,
              name: "idx_stock_achievements_portfolio_key"
  end
end
