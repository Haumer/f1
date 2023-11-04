class CreateCircuits < ActiveRecord::Migration[7.0]
  def change
    create_table :circuits do |t|
      t.integer :kaggle_id
      t.string :circuit_ref
      t.string :name
      t.string :location
      t.string :country
      t.float :lat
      t.float :lng
      t.integer :alt
      t.string :url

      t.timestamps
    end
  end
end
