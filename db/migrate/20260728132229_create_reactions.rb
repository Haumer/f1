class CreateReactions < ActiveRecord::Migration[7.2]
  def change
    create_table :reactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :reactable, polymorphic: true, null: false
      t.string :kind, null: false
      t.timestamps
    end

    add_index :reactions,
              [:user_id, :reactable_type, :reactable_id, :kind],
              unique: true,
              name: "idx_reactions_unique_per_user_target_kind"
    add_index :reactions,
              [:reactable_type, :reactable_id, :kind],
              name: "idx_reactions_by_target_kind"
  end
end
