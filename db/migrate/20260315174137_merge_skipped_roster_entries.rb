class MergeSkippedRosterEntries < ActiveRecord::Migration[7.0]
  # Fix: the previous migration skipped roster entries where the user already
  # had a stock holding for the same driver. Those users paid cash for the
  # roster slot but got no shares. This merges the 10 converted shares into
  # the existing holding (weighted average entry price).
  def up
    # Find active roster entries that were NOT converted (skipped because
    # a stock holding already existed)
    skipped = execute(<<~SQL).to_a
      SELECT fre.id, fre.driver_id, fre.bought_at_elo, fre.bought_race_id, fre.created_at,
             fsp.id AS stock_portfolio_id,
             fsh.id AS holding_id, fsh.quantity AS existing_qty, fsh.entry_price AS existing_price
      FROM fantasy_roster_entries fre
      JOIN fantasy_portfolios fp ON fp.id = fre.fantasy_portfolio_id
      JOIN fantasy_stock_portfolios fsp ON fsp.user_id = fp.user_id AND fsp.season_id = fp.season_id
      JOIN fantasy_stock_holdings fsh ON fsh.fantasy_stock_portfolio_id = fsp.id
                                      AND fsh.driver_id = fre.driver_id
                                      AND fsh.direction = 'long'
                                      AND fsh.active = true
      WHERE fre.active = true
        AND fsh.quantity != 10  -- skip already-converted (those are exactly 10)
    SQL

    skipped.each do |row|
      holding_id = row["holding_id"]
      existing_qty = row["existing_qty"].to_i
      existing_price = row["existing_price"].to_f
      convert_qty = 10
      convert_price = row["bought_at_elo"].to_f / 10.0

      new_qty = existing_qty + convert_qty
      new_price = ((existing_price * existing_qty) + (convert_price * convert_qty)) / new_qty

      execute(<<~SQL)
        UPDATE fantasy_stock_holdings
        SET quantity = #{new_qty}, entry_price = #{new_price}
        WHERE id = #{holding_id}
      SQL

      # Update net_demand
      execute(<<~SQL)
        UPDATE season_drivers sd
        SET net_demand = COALESCE(sd.net_demand, 0) + #{convert_qty}
        FROM fantasy_stock_portfolios fsp
        WHERE fsp.id = #{row["stock_portfolio_id"]}
          AND sd.driver_id = #{row["driver_id"]}
          AND sd.season_id = fsp.season_id
      SQL
    end

    say "Merged #{skipped.size} skipped roster entries into existing holdings"
  end

  def down
    # Not reversible — would need to know which holdings were merged
  end
end
