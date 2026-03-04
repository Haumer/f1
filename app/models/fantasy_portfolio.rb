class FantasyPortfolio < ApplicationRecord
  belongs_to :user
  belongs_to :season

  has_many :roster_entries, class_name: "FantasyRosterEntry", dependent: :destroy
  has_many :transactions, class_name: "FantasyTransaction", dependent: :destroy

  validates :user_id, uniqueness: { scope: :season_id }
  validates :cash, :starting_capital, presence: true

  def active_roster_entries
    roster_entries.where(active: true)
  end

  def active_drivers
    Driver.where(id: active_roster_entries.select(:driver_id))
  end

  def portfolio_value
    cash + active_roster_entries.includes(:driver).sum { |e| e.driver.elo_v2 || 0 }
  end

  def profit_loss
    portfolio_value - starting_capital
  end

  def can_trade?(race)
    return false unless race&.starts_at
    race.starts_at > Time.current && swaps_this_race(race) < 1
  end

  def swaps_this_race(race)
    roster_entries.where(sold_race_id: race.id).count
  end

  def roster_full?
    active_roster_entries.count >= 2
  end

  def has_driver?(driver)
    active_roster_entries.exists?(driver_id: driver.id)
  end

  def held_races_for(driver)
    entry = active_roster_entries.find_by(driver_id: driver.id)
    return 0 unless entry

    bought_round = entry.bought_race&.round || 0
    current_round = season.latest_race&.round || 0
    current_round - bought_round
  end

  # Login streak bonus: streak * 5, capped at 50
  LOGIN_BONUS_PER_DAY = 5
  LOGIN_BONUS_CAP = 50

  def record_login!
    today = Date.current
    return if last_login_date == today

    if last_login_date == today - 1
      self.login_streak += 1
    else
      self.login_streak = 1
    end

    bonus = [login_streak * LOGIN_BONUS_PER_DAY, LOGIN_BONUS_CAP].min
    self.cash += bonus
    self.last_login_date = today

    save!
    transactions.create!(kind: "login_bonus", amount: bonus, note: "Day #{login_streak} streak")
    bonus
  end

  # Interaction bonus: 10 per interaction, max 3/day
  INTERACTION_BONUS = 10
  MAX_INTERACTIONS_PER_DAY = 3

  def record_interaction!
    today = Date.current

    if last_interaction_date != today
      self.interactions_today = 0
      self.last_interaction_date = today
    end

    return false if interactions_today >= MAX_INTERACTIONS_PER_DAY

    self.interactions_today += 1
    self.cash += INTERACTION_BONUS
    save!
    transactions.create!(kind: "interaction_bonus", amount: INTERACTION_BONUS, note: "Interaction #{interactions_today}/#{MAX_INTERACTIONS_PER_DAY}")
    true
  end
end
