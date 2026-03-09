class AddNetDemandToSeasonDrivers < ActiveRecord::Migration[7.0]
  def change
    add_column :season_drivers, :net_demand, :integer, default: 0, null: false
  end

  # Backfill from existing holdings
  # Run after migration: rails runner /tmp/backfill_net_demand.rb
end
