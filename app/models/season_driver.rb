class SeasonDriver < ApplicationRecord
  belongs_to :driver
  belongs_to :season
  belongs_to :constructor

  # Atomically adjust net_demand (longs add, shorts subtract)
  def self.adjust_demand!(driver_id, season_id, delta)
    sd = find_by!(driver_id: driver_id, season_id: season_id)
    sd.with_lock do
      sd.update!(net_demand: sd.net_demand + delta)
    end
  end
end
