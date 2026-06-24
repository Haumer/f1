module FantasyActivityHelper
  ACTIVITY_KIND_LABELS = {
    "buy"               => "Buy",
    "sell"              => "Sell",
    "short_open"        => "Short open",
    "short_close"       => "Short close",
    "dividend"          => "Dividend",
    "borrow_fee"        => "Borrow fee",
    "liquidation"       => "Liquidation",
    "starting_capital"  => "Opening balance",
    "roster_conversion" => "Converted roster",
    "pick_reward"       => "Pick reward",
    "card_earned"       => "Card earned",
    "card_combined"     => "Cards combined",
    "achievement_earned" => "Achievement",
    "team_purchase"     => "Bought team",
    "bonus"             => "Bonus"
  }.freeze

  ACTIVITY_KIND_ICONS = {
    "buy"               => "fa-arrow-down",
    "sell"              => "fa-arrow-up",
    "short_open"        => "fa-arrow-trend-down",
    "short_close"       => "fa-arrow-trend-up",
    "dividend"          => "fa-coins",
    "borrow_fee"        => "fa-percent",
    "liquidation"       => "fa-triangle-exclamation",
    "starting_capital"  => "fa-flag",
    "roster_conversion" => "fa-right-left",
    "pick_reward"       => "fa-trophy",
    "card_earned"       => "fa-id-card",
    "card_combined"     => "fa-object-group",
    "achievement_earned" => "fa-medal",
    "team_purchase"     => "fa-users-rectangle",
    "bonus"             => "fa-gift"
  }.freeze

  def activity_kind_label(kind)
    ACTIVITY_KIND_LABELS[kind.to_s] || kind.to_s.humanize
  end

  def activity_kind_icon(kind)
    ACTIVITY_KIND_ICONS[kind.to_s]
  end
end
