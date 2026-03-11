class CreateRacePicks < ActiveRecord::Migration[7.0]
  def change
    create_table :race_picks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :race, null: false, foreign_key: true
      t.jsonb :picks, default: []
      t.integer :score
      t.datetime :locked_at

      t.timestamps
    end

    add_index :race_picks, [:user_id, :race_id], unique: true
  end
end
