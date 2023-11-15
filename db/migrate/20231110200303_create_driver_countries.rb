class CreateDriverCountries < ActiveRecord::Migration[7.0]
  def change
    create_table :driver_countries do |t|
      t.references :driver, null: false, foreign_key: true
      t.references :country, null: false, foreign_key: true

      t.timestamps
    end
  end
end
