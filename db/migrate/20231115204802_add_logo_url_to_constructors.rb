class AddLogoUrlToConstructors < ActiveRecord::Migration[7.0]
  def change
    add_column :constructors, :logo_url, :string
  end
end
