class AddNullFalseToRaces < ActiveRecord::Migration[7.0]
  def change
    change_column_null :races, :season_id, false
  end
end
