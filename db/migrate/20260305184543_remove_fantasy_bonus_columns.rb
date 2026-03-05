class RemoveFantasyBonusColumns < ActiveRecord::Migration[7.0]
  def change
    remove_column :fantasy_portfolios, :login_streak, :integer, default: 0
    remove_column :fantasy_portfolios, :last_login_date, :date
    remove_column :fantasy_portfolios, :interactions_today, :integer, default: 0
    remove_column :fantasy_portfolios, :last_interaction_date, :date
  end
end
