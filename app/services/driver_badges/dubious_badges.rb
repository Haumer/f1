module DriverBadges::DubiousBadges
  private

  def check_clean_racer
    total = total_races
    crashes = total_crashes
    return unless total >= 80 && crashes <= 5

    @badges << Badge.new(
      key: :clean_racer,
      label: "Clean Racer",
      description: "Only #{crashes} accident DNFs in #{total} races",
      icon: "fa-solid fa-broom",
      color: "green",
      value: crashes
    )
  end

  def check_crash_king
    crashes = total_crashes
    total = total_races
    return unless crashes >= 25

    rate = (crashes.to_f / total * 100).round(1)
    @badges << Badge.new(
      key: :crash_king,
      label: "The Maldonado",
      description: "#{crashes} accident-related DNFs (#{rate}% of races)",
      icon: "fa-solid fa-car-burst",
      color: "crimson",
      value: crashes
    )
  end

  def check_mechanical_magnet
    mech = total_mechanical
    total = total_races
    return unless mech >= 30

    rate = (mech.to_f / total * 100).round(1)
    @badges << Badge.new(
      key: :mechanical_magnet,
      label: "Cursed Machinery",
      description: "#{mech} mechanical DNFs (#{rate}% of races)",
      icon: "fa-solid fa-screwdriver-wrench",
      color: "crimson",
      value: mech
    )
  end

  def check_backmarker
    total = total_races
    outside = total_outside_top_ten
    return unless total >= 80 && outside.to_f / total >= 0.60

    rate = (outside.to_f / total * 100).round(1)
    @badges << Badge.new(
      key: :backmarker,
      label: "Off the Pace",
      description: "#{rate}% of races finished outside the top 10 (#{outside}/#{total})",
      icon: "fa-solid fa-face-sad-tear",
      color: "gray",
      value: "#{rate}%"
    )
  end

  def check_lapped
    lapped = total_lapped
    total = total_races
    return unless lapped >= 50

    rate = (lapped.to_f / total * 100).round(1)
    @badges << Badge.new(
      key: :lapped,
      label: "Blue Flag Special",
      description: "Lapped in #{lapped} races (#{rate}% of career)",
      icon: "fa-solid fa-flag",
      color: "gray",
      value: lapped
    )
  end

  def check_constructor_nomad
    teams = @race_results.filter_map(&:constructor).uniq
    return unless teams.size >= 4

    label = teams.size >= 7 ? "Journeyman" : "Team Hopper"
    @badges << Badge.new(
      key: :constructor_nomad,
      label: label,
      description: "Raced for #{teams.size} different constructors",
      icon: "fa-solid fa-shuffle",
      color: "purple",
      value: teams.size
    )
  end

  def check_bridesmaid
    second_places = total_second_places
    return unless second_places >= 20

    @badges << Badge.new(
      key: :bridesmaid,
      label: "Always the Bridesmaid",
      description: "#{second_places} career 2nd-place finishes",
      icon: "fa-solid fa-heart-crack",
      color: "silver",
      value: second_places
    )
  end

  def check_fourth_place_specialist
    fourths = total_fourth_places
    return unless fourths >= 20

    @badges << Badge.new(
      key: :fourth_place_specialist,
      label: "Wooden Spoon",
      description: "#{fourths} career 4th-place finishes — so close to the podium",
      icon: "fa-solid fa-face-meh",
      color: "gray",
      value: fourths
    )
  end

  def check_hulkenberg_award
    total = total_races
    podiums = total_podiums
    return unless total >= 50 && podiums == 0

    @badges << Badge.new(
      key: :hulkenberg_award,
      label: "The Hülkenberg",
      description: "#{total} races without a podium finish",
      icon: "fa-solid fa-ghost",
      color: "gray",
      value: total
    )
  end
end
