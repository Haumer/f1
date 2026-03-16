class RemoveRosterSystemConvertToStocks < ActiveRecord::Migration[7.0]
  def up
    # Phase 1: Ensure every user with a roster portfolio also has a stock portfolio
    execute <<~SQL
      INSERT INTO fantasy_stock_portfolios (user_id, season_id, cash, starting_capital, created_at, updated_at)
      SELECT fp.user_id, fp.season_id, 0, 0, fp.created_at, NOW()
      FROM fantasy_portfolios fp
      WHERE NOT EXISTS (
        SELECT 1 FROM fantasy_stock_portfolios fsp
        WHERE fsp.user_id = fp.user_id AND fsp.season_id = fp.season_id
      )
    SQL

    # Phase 2: Convert active roster entries to stock holdings (10 shares each)
    # Entry price = bought_at_elo / 10 (stock price divisor)
    execute <<~SQL
      INSERT INTO fantasy_stock_holdings
        (fantasy_stock_portfolio_id, driver_id, quantity, direction, entry_price, opened_race_id, active, created_at, updated_at)
      SELECT
        fsp.id,
        fre.driver_id,
        10,
        'long',
        fre.bought_at_elo / 10.0,
        COALESCE(fre.bought_race_id, (SELECT r.id FROM races r JOIN seasons s ON s.id = r.season_id WHERE s.id = fp.season_id ORDER BY r.round LIMIT 1)),
        true,
        fre.created_at,
        NOW()
      FROM fantasy_roster_entries fre
      JOIN fantasy_portfolios fp ON fp.id = fre.fantasy_portfolio_id
      JOIN fantasy_stock_portfolios fsp ON fsp.user_id = fp.user_id AND fsp.season_id = fp.season_id
      WHERE fre.active = true
        AND NOT EXISTS (
          SELECT 1 FROM fantasy_stock_holdings fsh
          WHERE fsh.fantasy_stock_portfolio_id = fsp.id
            AND fsh.driver_id = fre.driver_id
            AND fsh.direction = 'long'
            AND fsh.active = true
        )
    SQL

    # Phase 3: Update net_demand for converted holdings
    execute <<~SQL
      UPDATE season_drivers sd
      SET net_demand = COALESCE(sd.net_demand, 0) + sub.total_qty
      FROM (
        SELECT fsh.driver_id, fsp.season_id, SUM(fsh.quantity) as total_qty
        FROM fantasy_stock_holdings fsh
        JOIN fantasy_stock_portfolios fsp ON fsp.id = fsh.fantasy_stock_portfolio_id
        WHERE fsh.active = true
          AND fsh.quantity = 10
          AND fsh.direction = 'long'
          AND fsh.entry_price = (
            SELECT fre.bought_at_elo / 10.0
            FROM fantasy_roster_entries fre
            JOIN fantasy_portfolios fp ON fp.id = fre.fantasy_portfolio_id
            WHERE fp.user_id = fsp.user_id AND fp.season_id = fsp.season_id
              AND fre.driver_id = fsh.driver_id AND fre.active = true
            LIMIT 1
          )
        GROUP BY fsh.driver_id, fsp.season_id
      ) sub
      WHERE sd.driver_id = sub.driver_id AND sd.season_id = sub.season_id
    SQL

    # Phase 4: Remove roster-specific columns from fantasy_portfolios
    remove_column :fantasy_portfolios, :roster_slots, :integer, default: 2
  end

  def down
    add_column :fantasy_portfolios, :roster_slots, :integer, default: 2
  end
end
