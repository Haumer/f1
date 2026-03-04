class AddTimeToRaces < ActiveRecord::Migration[7.0]
  def change
    add_column :races, :time, :string
    add_column :races, :fp1_time, :string
    add_column :races, :fp2_time, :string
    add_column :races, :fp3_time, :string
    add_column :races, :quali_time, :string
  end
end
