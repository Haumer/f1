class CreateCareers < ActiveRecord::Migration[7.0]
  def change
    create_table :careers do |t|
      t.integer :podiums
      t.integer :wins
      t.integer :second_places
      t.integer :third_places
      t.integer :fourth_places
      t.integer :fifth_places
      t.integer :sixth_places
      t.integer :seventh_places
      t.integer :eighth_places
      t.integer :nineth_places
      t.integer :tenth_places
      t.integer :outside_of_top_ten
      t.float :peak_elo
      t.float :lowest_elo
      t.integer :crash_races
      t.integer :technichal_failures_races
      t.integer :disqualified_races
      t.integer :lapped_races
      t.integer :finished_races
      t.integer :total_races
      t.integer :fastest_laps
      t.references :driver, null: false, foreign_key: true
      t.date :first_race_date
      t.date :last_race_date

      t.timestamps
    end
  end
end
