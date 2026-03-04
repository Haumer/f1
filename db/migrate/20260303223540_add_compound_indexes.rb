class AddCompoundIndexes < ActiveRecord::Migration[7.0]
  def change
    # driver_standings: queried by (race_id, driver_id) in rankings, standings lookups
    add_index :driver_standings, [:race_id, :driver_id], unique: true

    # driver_standings: season_end champions query
    add_index :driver_standings, [:season_end, :position], where: "season_end = true"

    # race_results: queried by (race_id, driver_id) in standings data
    add_index :race_results, [:race_id, :driver_id]

    # race_results: queried by (driver_id, race_id) in driver graph line
    add_index :race_results, [:driver_id, :race_id]

    # season_drivers: queried by (season_id, driver_id) in standings extras
    add_index :season_drivers, [:season_id, :driver_id]

    # races: queried by (season_id, round) for ordering within a season
    add_index :races, [:season_id, :round]

    # races: queried by (season_id, date) for date-ordered season queries
    add_index :races, [:season_id, :date]
  end
end
