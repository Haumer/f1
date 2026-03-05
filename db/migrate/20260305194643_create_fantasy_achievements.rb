class CreateFantasyAchievements < ActiveRecord::Migration[7.0]
  def change
    create_table :fantasy_achievements do |t|
      t.references :fantasy_portfolio, null: false, foreign_key: true
      t.string :key
      t.string :tier
      t.datetime :earned_at

      t.timestamps
    end

    add_index :fantasy_achievements, [:fantasy_portfolio_id, :key], unique: true
  end
end
