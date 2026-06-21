class AddCombinedFromRaceIdsToDriverCards < ActiveRecord::Migration[7.2]
  def change
    add_column :driver_cards, :combined_from_race_ids, :integer, array: true, default: [], null: false
  end
end
