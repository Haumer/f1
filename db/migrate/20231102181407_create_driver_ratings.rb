class CreateDriverRatings < ActiveRecord::Migration[7.0]
  def change
    create_table :driver_ratings do |t|
      t.references :driver, null: false, foreign_key: true
      t.references :race, null: false, foreign_key: true
      t.integer :rating
      t.boolean :peak_rating, default: false

      t.timestamps
    end
  end
end
