class AddCancelledToRaces < ActiveRecord::Migration[7.0]
  def change
    add_column :races, :cancelled, :boolean, default: false, null: false
    add_index :races, :cancelled
  end
end
