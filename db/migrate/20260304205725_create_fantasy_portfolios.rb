class CreateFantasyPortfolios < ActiveRecord::Migration[7.0]
  def change
    create_table :fantasy_portfolios do |t|
      t.references :user, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.float :cash, null: false, default: 0
      t.float :starting_capital, null: false
      t.integer :login_streak, default: 0
      t.date :last_login_date
      t.integer :interactions_today, default: 0
      t.date :last_interaction_date

      t.timestamps
    end

    add_index :fantasy_portfolios, [:user_id, :season_id], unique: true
  end
end
