class CreateQualifyingResults < ActiveRecord::Migration[7.0]
  def change
    create_table :qualifying_results do |t|
      t.references :race, null: false, foreign_key: true
      t.references :driver, null: false, foreign_key: true
      t.references :constructor, foreign_key: true
      t.integer :position
      t.string :q1
      t.string :q2
      t.string :q3

      t.timestamps
    end
  end
end
