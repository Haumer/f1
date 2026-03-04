class CreateFantasyTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :fantasy_transactions do |t|
      t.references :fantasy_portfolio, null: false, foreign_key: true
      t.string :kind, null: false
      t.float :amount, null: false
      t.references :driver, foreign_key: true
      t.references :race, foreign_key: true
      t.string :note

      t.timestamps
    end
  end
end
