class AddSupportedConstructorToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :supported_constructor_id, :bigint
    add_index :users, :supported_constructor_id
    add_foreign_key :users, :constructors, column: :supported_constructor_id
  end
end
