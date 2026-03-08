module DriverBadges::RaceBadges
  private

  def check_consecutive_wins
    streak = longest_streak(@sorted_results) { |rr| rr.position_order == 1 }
    return unless streak >= 3

    @badges << DriverBadges::Badge.new(
      key: :consecutive_wins,
      label: "On Fire",
      description: "#{streak} consecutive race wins",
      icon: "fa-solid fa-fire",
      color: "gold",
      value: streak
    )
  end

  def check_consecutive_podiums
    streak = longest_streak(@sorted_results) { |rr| rr.position_order && rr.position_order <= 3 }
    return unless streak >= 5

    @badges << DriverBadges::Badge.new(
      key: :consecutive_podiums,
      label: "Podium Machine",
      description: "#{streak} consecutive podium finishes",
      icon: "fa-solid fa-bolt-lightning",
      color: "bronze",
      value: streak
    )
  end

  def check_pole_to_win
    pole_wins = @sorted_results.count { |rr| rr.grid == 1 && rr.position_order == 1 }
    return unless pole_wins >= 3

    @badges << DriverBadges::Badge.new(
      key: :pole_to_win,
      label: "Lights to Flag",
      description: "#{pole_wins} pole-to-victory conversions",
      icon: "fa-solid fa-flag-checkered",
      color: "red",
      value: pole_wins
    )
  end

  def check_recovery_drive
    recoveries = @sorted_results.select do |rr|
      rr.grid && rr.grid >= 15 && rr.position_order && rr.position_order <= 3
    end
    return unless recoveries.any?

    best = recoveries.max_by { |rr| rr.grid - rr.position_order }
    gained = best.grid - best.position_order

    @badges << DriverBadges::Badge.new(
      key: :recovery_drive,
      label: "Recovery Artist",
      description: "Started P#{best.grid}, finished P#{best.position_order} at #{best.race.circuit.name}",
      icon: "fa-solid fa-heart-pulse",
      color: "green",
      value: "+#{gained}"
    )
  end

  def check_comeback_king
    valid = @sorted_results.select { |rr| rr.grid && rr.grid > 0 && rr.position_order && rr.position_order > 0 }
    best = valid.max_by { |rr| rr.grid - rr.position_order }
    return unless best && (best.grid - best.position_order) >= 15

    gained = best.grid - best.position_order
    @badges << DriverBadges::Badge.new(
      key: :comeback_king,
      label: "Comeback King",
      description: "Gained #{gained} places in a single race (P#{best.grid} → P#{best.position_order})",
      icon: "fa-solid fa-jet-fighter-up",
      color: "blue",
      value: "+#{gained}"
    )
  end
end
