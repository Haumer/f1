module DriverBadges::CareerBadges
  private

  def check_rookie_win
    wins = rookie_season_results.select { |rr| rr.position_order == 1 }
    return unless wins.any?

    add_badge(:rookie_win,
      label: "Rookie Winner", description: "#{wins.size} win#{'s' if wins.size > 1} in debut season (#{wins.first.race.date.year})",
      icon: "fa-solid fa-seedling", color: "gold", value: wins.size)
  end

  def check_rookie_podium
    podiums = rookie_season_results.select { |rr| rr.position_order && rr.position_order <= 3 }
    return unless podiums.any?
    return if podiums.any? { |rr| rr.position_order == 1 }

    add_badge(:rookie_podium,
      label: "Rookie Podium", description: "#{podiums.size} podium#{'s' if podiums.size > 1} in debut season (#{podiums.first.race.date.year})",
      icon: "fa-solid fa-seedling", color: "green", value: podiums.size)
  end

  def check_one_hit_wonder
    wins = total_wins
    total = total_races
    return unless wins == 1 && total >= 20

    win_rr = @sorted_results.find { |rr| rr.position_order == 1 }
    where = win_rr ? " at #{win_rr.race.circuit.name}" : ""

    add_badge(:one_hit_wonder,
      label: "One Hit Wonder", description: "1 win in #{total} races#{where}",
      icon: "fa-solid fa-dice-one", color: "purple", value: "1/#{total}")
  end

  def check_century_club
    total = total_races
    return unless total >= 100

    tier, icon = if total >= 300
                   ["Triple Century", "fa-solid fa-certificate"]
                 elsif total >= 200
                   ["Double Century", "fa-solid fa-award"]
                 else
                   ["Century Club", "fa-solid fa-medal"]
                 end

    add_badge(:century_club,
      label: tier, description: "#{total} career race starts",
      icon: icon, color: "silver", value: total)
  end

  def check_finishes_milestone
    finished = total_finished
    return unless finished >= 50

    label, icon = if finished >= 200
                    ["200 Finishes", "fa-solid fa-star"]
                  elsif finished >= 150
                    ["150 Finishes", "fa-solid fa-certificate"]
                  elsif finished >= 100
                    ["100 Finishes", "fa-solid fa-award"]
                  else
                    ["50 Finishes", "fa-solid fa-medal"]
                  end

    add_badge(:finishes_milestone,
      label: label, description: "#{finished} classified race finishes",
      icon: icon, color: "green", value: finished)
  end

  def check_loyal_servant
    return if @sorted_results.size < 50

    max_streak = 0
    max_constructor = nil
    cur_streak = 0
    cur_constructor_id = nil

    @sorted_results.each do |rr|
      if rr.constructor_id == cur_constructor_id
        cur_streak += 1
      else
        cur_streak = 1
        cur_constructor_id = rr.constructor_id
      end
      if cur_streak > max_streak
        max_streak = cur_streak
        max_constructor = rr.constructor
      end
    end

    return unless max_streak >= 80

    pct = (max_streak.to_f / total_races * 100).round(0)
    add_badge(:loyal_servant,
      label: "Loyal Servant", description: "#{max_streak} consecutive races with #{max_constructor&.name} (#{pct}% of career)",
      icon: "fa-solid fa-handshake", color: "blue", value: max_streak)
  end

  def check_dynamic_duo
    race_ids = @sorted_results.map(&:race_id)
    return if race_ids.empty?

    constructor_by_race = @sorted_results.each_with_object({}) { |rr, h| h[rr.race_id] = rr.constructor_id }
    all_teammate_results = RaceResult.where(race_id: race_ids)
                                     .where.not(driver_id: @driver.id)
                                     .pluck(:race_id, :driver_id, :constructor_id)

    teammate_counts = Hash.new(0)
    all_teammate_results.each do |race_id, driver_id, constructor_id|
      teammate_counts[driver_id] += 1 if constructor_id == constructor_by_race[race_id]
    end
    return if teammate_counts.empty?

    best_id, count = teammate_counts.max_by { |_, c| c }
    return unless count >= 60

    teammate = Driver.find_by(id: best_id)
    return unless teammate

    add_badge(:dynamic_duo,
      label: "Dynamic Duo", description: "#{count} races alongside #{teammate.forename.first}.#{teammate.surname}",
      icon: "fa-solid fa-user-group", color: "blue", value: count)
  end

  def check_iron_man
    total = total_races
    finished = total_finished
    return unless total >= 50 && finished.to_f / total >= 0.90

    rate = (finished.to_f / total * 100).round(1)
    add_badge(:iron_man,
      label: "Iron Man", description: "#{rate}% finish rate over #{total} races",
      icon: "fa-solid fa-shield-halved", color: "steel", value: "#{rate}%")
  end

  def check_points_machine
    total = total_races
    return unless total >= 50

    points_finishes = @sorted_results.count { |rr| rr.position_order && rr.position_order <= 10 }
    rate = (points_finishes.to_f / total * 100).round(1)
    return unless rate >= 70

    add_badge(:points_machine,
      label: "Points Machine", description: "#{rate}% points-scoring rate (#{points_finishes}/#{total} races)",
      icon: "fa-solid fa-bullseye", color: "blue", value: "#{rate}%")
  end
end
