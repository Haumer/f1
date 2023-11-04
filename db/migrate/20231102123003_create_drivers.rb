class CreateDrivers < ActiveRecord::Migration[7.0]
  def change
    create_table :drivers do |t|
      t.integer :kaggle_id
      t.string :driver_ref
      t.integer :number
      t.string :code
      t.string :forename
      t.string :surname
      t.string :dob
      t.string :nationality
      t.string :url
      t.integer :elo

      t.timestamps
    end
  end
end
