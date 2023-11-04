class AddFirstAndLastRaceDate < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers, :first_race_date, :date
    add_column :drivers, :last_race_date, :date
  end
end
