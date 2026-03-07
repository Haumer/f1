module DriverBadges::EloBadges
  private

  def check_elo_rocket
    return if @sorted_results.empty?

    best = @sorted_results.max_by { |rr| rr.display_elo_diff || 0 }
    return unless best && (best.display_elo_diff || 0) >= 80

    @badges << Badge.new(
      key: :elo_rocket,
      label: "Elo Rocket",
      description: "+#{best.display_elo_diff.round(1)} Elo in a single race at #{best.race.circuit.name}",
      icon: "fa-solid fa-rocket",
      color: "orange",
      value: "+#{best.display_elo_diff.round(1)}"
    )
  end

  def check_elo_freefall
    return if @sorted_results.empty?

    worst = @sorted_results.min_by { |rr| rr.display_elo_diff || 0 }
    return unless worst && (worst.display_elo_diff || 0) <= -80

    @badges << Badge.new(
      key: :elo_freefall,
      label: "Elo Crater",
      description: "#{worst.display_elo_diff.round(1)} Elo in a single race at #{worst.race.circuit.name}",
      icon: "fa-solid fa-meteor",
      color: "crimson",
      value: worst.display_elo_diff.round(1)
    )
  end
end
