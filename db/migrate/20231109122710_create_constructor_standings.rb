class CreateConstructorStandings < ActiveRecord::Migration[7.0]
  def change
    create_table :constructor_standings do |t|
      t.string :kaggle_id
      t.references :race, null: false, foreign_key: true
      t.references :constructor, null: false, foreign_key: true
      t.float :points
      t.integer :position
      t.integer :wins

      t.timestamps
    end
  end
end
