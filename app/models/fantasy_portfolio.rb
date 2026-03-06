class FantasyPortfolio < ApplicationRecord
  belongs_to :user
  belongs_to :season

  has_many :roster_entries, class_name: "FantasyRosterEntry", dependent: :destroy
  has_many :transactions, class_name: "FantasyTransaction", dependent: :destroy
  has_many :snapshots, class_name: "FantasySnapshot", dependent: :destroy
  has_many :achievements, class_name: "FantasyAchievement", dependent: :destroy

  validates :user_id, uniqueness: { scope: :season_id }
  validates :cash, :starting_capital, presence: true

  def active_roster_entries
    roster_entries.where(active: true)
  end

  def active_drivers
    Driver.where(id: active_roster_entries.select(:driver_id))
  end

  def portfolio_value
    cash + active_roster_entries.includes(:driver).sum { |e| Fantasy::Pricing.price_for(e.driver, season) }
  end

  def profit_loss
    portfolio_value - starting_capital
  end

  def can_trade?(race)
    return false unless race&.starts_at
    race.starts_at > Time.current && swaps_this_race(race) < max_swaps_per_race
  end

  def swaps_this_race(race)
    roster_entries.where(sold_race_id: race.id).count
  end

  def roster_full?
    active_roster_entries.count >= roster_slots
  end

  def max_swaps_per_race
    roster_slots / SLOTS_PER_TEAM  # 1 swap per team
  end

  def teams_owned
    roster_slots / SLOTS_PER_TEAM
  end

  def can_buy_team?
    teams_owned < MAX_TEAMS
  end

  def team_cost
    avg = Driver.where.not(elo_v2: nil)
                .joins(:season_drivers)
                .where(season_drivers: { season_id: season_id })
                .average(:elo_v2) || 0
    avg.round(0)
  end

  def has_driver?(driver)
    active_roster_entries.exists?(driver_id: driver.id)
  end

  def has_achievement?(key)
    achievements.exists?(key: key.to_s)
  end

  STARTING_SLOTS = 2
  SLOTS_PER_TEAM = 2
  MAX_TEAMS = 3
  MAX_ROSTER_SIZE = MAX_TEAMS * SLOTS_PER_TEAM  # 6

  def held_races_for(driver)
    entry = active_roster_entries.find_by(driver_id: driver.id)
    return 0 unless entry

    bought_race = entry.bought_race
    return 0 unless bought_race

    latest = season.latest_race
    return 0 unless latest

    latest.round - bought_race.round
  end

  def value_change_since_last_race
    last_two = snapshots.order(created_at: :desc).limit(2).to_a
    return nil if last_two.size < 2
    last_two[0].value - last_two[1].value
  end
end
