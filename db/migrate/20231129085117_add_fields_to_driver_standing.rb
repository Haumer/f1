class AddFieldsToDriverStanding < ActiveRecord::Migration[7.0]
  def change
    add_column :driver_standings, :fourth_places, :integer
    add_column :driver_standings, :fifth_places, :integer
    add_column :driver_standings, :sixth_places, :integer
    add_column :driver_standings, :seventh_places, :integer
    add_column :driver_standings, :eighth_places, :integer
    add_column :driver_standings, :nineth_places, :integer
    add_column :driver_standings, :tenth_places, :integer
    add_column :driver_standings, :outside_of_top_ten, :integer

    add_column :driver_standings, :crash_races, :integer
    add_column :driver_standings, :technichal_failures_races, :integer
    add_column :driver_standings, :disqualified_races, :integer
    add_column :driver_standings, :lapped_races, :integer
    add_column :driver_standings, :finished_races, :integer
    add_column :driver_standings, :fastest_laps, :integer
    add_column :careers, :points, :integer
  end
end
