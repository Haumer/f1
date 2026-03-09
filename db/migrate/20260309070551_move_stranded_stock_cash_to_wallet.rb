class MoveStrandedStockCashToWallet < ActiveRecord::Migration[7.0]
  def up
    FantasyStockPortfolio.where("cash > 0").find_each do |sp|
      wallet = FantasyPortfolio.find_by(user_id: sp.user_id, season_id: sp.season_id)
      next unless wallet

      wallet.update!(cash: wallet.cash + sp.cash)
      sp.update!(cash: 0)
    end
  end

  def down
    # Not reversible — cash has been merged
  end
end
