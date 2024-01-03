class AddCareerInfoToDrivers < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers, :podiums, :integer
    add_column :drivers, :wins, :integer
    add_column :drivers, :second_places, :integer
    add_column :drivers, :third_places, :integer
    add_column :drivers, :fourth_places, :integer
    add_column :drivers, :fifth_places, :integer
    add_column :drivers, :sixth_places, :integer
    add_column :drivers, :seventh_places, :integer
    add_column :drivers, :eighth_places, :integer
    add_column :drivers, :nineth_places, :integer
    add_column :drivers, :tenth_places, :integer
    add_column :drivers, :outside_of_top_ten, :integer

    add_column :drivers, :crash_races, :integer
    add_column :drivers, :technichal_failures_races, :integer
    add_column :drivers, :disqualified_races, :integer
    add_column :drivers, :lapped_races, :integer
    add_column :drivers, :finished_races, :integer
    add_column :drivers, :fastest_laps, :integer
  end
end
