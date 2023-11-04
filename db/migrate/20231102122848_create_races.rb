class CreateRaces < ActiveRecord::Migration[7.0]
  def change
    create_table :races do |t|
      t.integer :kaggle_id
      t.integer :year
      t.integer :round
      t.date :date
      t.string :url
      t.references :circuit, null: false, foreign_key: true

      t.timestamps
    end
  end
end
