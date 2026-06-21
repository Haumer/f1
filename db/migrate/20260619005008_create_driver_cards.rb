class CreateDriverCards < ActiveRecord::Migration[7.2]
  def change
    create_table :driver_cards do |t|
      t.references :user, null: false, foreign_key: true
      t.references :driver, null: false, foreign_key: true
      t.references :race, null: false, foreign_key: true

      t.integer :predicted_position, null: false
      t.integer :actual_position, null: false
      t.string :tier, null: false # bronze / silver / gold / platinum / legendary

      # Career stats frozen at earn time — the card front renders the same
      # forever, even as the driver keeps racing. Lineage of how this card came
      # to be lives on the (driver, race, predicted_position) tuple.
      t.integer :snapshot_wins, null: false, default: 0
      t.integer :snapshot_podiums, null: false, default: 0
      t.integer :snapshot_wdc, null: false, default: 0
      t.float :snapshot_elo

      t.datetime :earned_at, null: false

      t.timestamps
    end

    # One card per (user, driver, race). Re-running the scorer must be idempotent.
    add_index :driver_cards, %i[user_id driver_id race_id], unique: true,
              name: "idx_driver_cards_unique_per_user_driver_race"
    add_index :driver_cards, %i[user_id tier]
  end
end
