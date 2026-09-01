module DriverCardsHelper
  TIER_ORDER = { "bronze" => 1, "silver" => 2, "gold" => 3, "platinum" => 4, "legendary" => 5 }.freeze
  TIER_BREAKDOWN_CLASS = {
    "bronze" => "br", "silver" => "si", "gold" => "go", "platinum" => "pt", "legendary" => "lg"
  }.freeze

  # Two-letter tier code, upper case. Single source of truth: the collection
  # summary hardcoded "BR SI GO PT LG" while the per-deck pills computed
  # `tier[0, 2].capitalize` ("Br Si Go Pl Le"), so one page showed two different
  # abbreviations for the same five tiers.
  def tier_abbrev(tier)
    (TIER_BREAKDOWN_CLASS[tier.to_s] || tier.to_s[0, 2]).upcase
  end

  # Full tier name, for tooltips and anywhere there is room to spell it out.
  def tier_label(tier)
    tier.to_s.capitalize
  end

  # CSS team-* class slug. Falls back to "team-default" with a neutral colour.
  def card_team_class(constructor)
    return "team-default" unless constructor&.constructor_ref
    "team-#{constructor.constructor_ref.tr('_', '-')}"
  end

  # Inline CSS custom property setting `--team-base`. The matching `--team-dark`
  # is derived in CSS via color-mix. Returns "" if no colour is known.
  def card_team_style(constructor)
    base = Constructor::COLORS[constructor&.constructor_ref&.to_sym]
    return "" unless base
    "--team-base: #{base};"
  end

  # 2–3 letter constructor crest (SF, RB, MCL, AM, MER, MCL, HAS).
  def constructor_crest(constructor)
    return "?" unless constructor
    case constructor.constructor_ref
    when "ferrari"      then "SF"
    when "red_bull"     then "RB"
    when "mercedes"     then "MER"
    when "mclaren"      then "MCL"
    when "aston_martin" then "AM"
    when "alpine"       then "ALP"
    when "williams"     then "WIL"
    when "haas"         then "HAS"
    when "sauber"       then "KS"
    when "rb"           then "RB"
    when "audi"         then "AUD"
    when "cadillac"     then "CAD"
    else                     constructor.name.to_s.split.first.to_s[0, 3].upcase
    end
  end

  # 3-letter driver code (HAM, VER, NOR…) falling back to surname uppercase.
  def driver_code(driver)
    (driver.code.presence || driver.surname.to_s[0, 3]).upcase
  end

  # Cards earned for the same (user, driver) tuple, sorted by tier rarity (top
  # of the stack = rarest). Used to fan a stack: top → back-1 → back-2 …
  def stack_sorted(cards)
    cards.sort_by { |c| [-(TIER_ORDER[c.tier] || 0), -c.earned_at.to_i] }
  end

  # Tier histogram for a stack: { "bronze" => 2, "silver" => 1 }
  def tier_counts(cards)
    cards.group_by(&:tier).transform_values(&:count)
  end
end
