class AddBonusAwardedAtToDriverPreferenceSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :driver_preference_sessions, :bonus_awarded_at, :datetime
  end
end
