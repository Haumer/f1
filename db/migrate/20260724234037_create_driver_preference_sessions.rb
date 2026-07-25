class CreateDriverPreferenceSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :driver_preference_sessions do |t|
      t.references :user, foreign_key: true, null: true
      t.string :session_token, null: false
      t.integer :year, null: false
      t.integer :rounds_target, null: false, default: 10
      t.integer :rounds_played, null: false, default: 0
      t.references :champion_driver, foreign_key: { to_table: :drivers }, null: true
      t.datetime :started_at, null: false
      t.datetime :finished_at

      t.timestamps
    end

    add_index :driver_preference_sessions, :session_token
    add_index :driver_preference_sessions, [:year, :finished_at]

    create_table :driver_preference_matches do |t|
      t.references :driver_preference_session, null: false,
                   foreign_key: true, index: { name: "idx_dpm_on_session_id" }
      t.references :winner_driver, foreign_key: { to_table: :drivers }, null: false
      t.references :loser_driver,  foreign_key: { to_table: :drivers }, null: false
      t.integer :year, null: false
      t.integer :round_index, null: false
      t.string :tier, null: false # bottom | middle | top

      t.datetime :created_at, null: false
    end

    add_index :driver_preference_matches, [:year, :winner_driver_id],
              name: "idx_dpm_on_year_and_winner"
    add_index :driver_preference_matches, [:year, :loser_driver_id],
              name: "idx_dpm_on_year_and_loser"
    add_index :driver_preference_matches, [:driver_preference_session_id, :round_index],
              unique: true, name: "idx_dpm_on_session_and_round"
  end
end
