class AddUniqueIndexToUsersUsername < ActiveRecord::Migration[7.0]
  def up
    # Backfill existing users with username derived from email
    execute <<~SQL
      UPDATE users SET username = LOWER(SPLIT_PART(email, '@', 1))
      WHERE username IS NULL
    SQL

    # Handle potential duplicates from backfill
    execute <<~SQL
      UPDATE users SET username = username || id::text
      WHERE id NOT IN (
        SELECT MIN(id) FROM users GROUP BY username
      )
    SQL

    change_column_null :users, :username, false
    add_index :users, :username, unique: true
  end

  def down
    remove_index :users, :username
    change_column_null :users, :username, true
  end
end
