class AddRaceRefToDriverPreferenceSessions < ActiveRecord::Migration[7.2]
  def change
    add_reference :driver_preference_sessions, :race, null: true, foreign_key: true
    add_index :driver_preference_sessions, [:session_token, :race_id],
              name: "idx_dps_on_token_and_race"
  end
end
