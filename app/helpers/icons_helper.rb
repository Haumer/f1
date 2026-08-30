# Bespoke inline-SVG icon set.
#
# Font Awesome is still loaded for legacy call sites, but everywhere the icon is
# part of how the page reads — page heads, nav cards, empty states, the fantasy
# chips, achievements — we draw our own. FA's rounded, friendly glyphs fight the
# rest of the UI, which is a timing screen: straight lines, precise arcs, tabular
# numerals.
#
# House rules for anything added here:
#   * 24x24 viewBox, artwork inset to roughly 3..21 so weights look even
#   * stroke: currentColor, 1.75 width, round caps/joins (set on the <svg> root)
#   * fills are opt-in per element via fill="currentColor" stroke="none"
#   * geometric construction only — no hand-wavy blobs
#
# Named `ui_icon`, not `icon`: font-awesome-sass already defines an `icon`
# helper with a different arity (style, name, ...). Relying on helper-module
# precedence to win that name is fragile — it resolved differently between an
# autoload and a fresh boot — so the name is simply distinct.
#
# Usage:  <%= ui_icon "helmet" %>  <%= ui_icon "trend_up", size: 20, class: "gain" %>
module IconsHelper
  ICON_PATHS = {
    # ── Racing ────────────────────────────────────────────────────────
    "flag" => <<~SVG,
      <path d="M5.25 3v18"/>
      <path d="M5.25 4.5h13.5v9H5.25z"/>
      <path d="M5.25 4.5h6.75v4.5H5.25zM12 9h6.75v4.5H12z" fill="currentColor" stroke="none"/>
    SVG
    "helmet" => <<~SVG,
      <path d="M12 3.25A8.75 8.75 0 0 0 3.25 12v3.9A2.85 2.85 0 0 0 6.1 19h11.8a2.85 2.85 0 0 0 2.85-2.85V12A8.75 8.75 0 0 0 12 3.25Z"/>
      <path d="M20.7 10.4 12.5 11.5a4.05 4.05 0 0 0-3.55 4.02v.23h11.75Z"/>
    SVG
    "tyre" => <<~SVG,
      <circle cx="12" cy="12" r="8.75"/>
      <circle cx="12" cy="12" r="3.75"/>
      <path d="M12 3.25V6.5M12 17.5v3.25M3.25 12H6.5M17.5 12h3.25"/>
    SVG
    "wheel" => <<~SVG,
      <circle cx="12" cy="12" r="9.25"/>
      <circle cx="12" cy="12" r="2.9"/>
      <path d="M3.1 10.5h17.8"/>
      <path d="M12 14.9v6.35"/>
    SVG
    "stopwatch" => <<~SVG,
      <circle cx="12" cy="13.75" r="7.5"/>
      <path d="M12 10v3.75l2.4 1.55"/>
      <path d="M9.5 2.75h5"/>
      <path d="M12 2.75v3.5"/>
      <path d="M18.95 6.65 20.5 5.1"/>
    SVG
    "podium" => <<~SVG,
      <path d="M9.25 8.75h5.5v11.5h-5.5z"/>
      <path d="M14.75 12.75h5.5v7.5h-5.5z"/>
      <path d="M3.75 14.75h5.5v5.5h-5.5z"/>
    SVG
    "trophy" => <<~SVG,
      <path d="M7.75 3.5h8.5v5A4.25 4.25 0 0 1 12 12.75 4.25 4.25 0 0 1 7.75 8.5z"/>
      <path d="M7.75 5.25H5.25V6.5a3 3 0 0 0 3 3"/>
      <path d="M16.25 5.25h2.5V6.5a3 3 0 0 1-3 3"/>
      <path d="M12 12.75V16"/>
      <path d="M8.5 20.5h7l-.85-4.5h-5.3z"/>
    SVG
    "circuit" => <<~SVG,
      <rect x="2.75" y="6.25" width="18.5" height="11.5" rx="5.75"/>
      <rect x="6.75" y="9.75" width="10.5" height="4.5" rx="2.25"/>
    SVG
    "pin" => <<~SVG,
      <path d="M19 10.25c0 5.25-7 10.5-7 10.5s-7-5.25-7-10.5a7 7 0 0 1 14 0Z"/>
      <circle cx="12" cy="10.1" r="2.6"/>
    SVG

    # ── Data / trend ──────────────────────────────────────────────────
    "telemetry" => <<~SVG,
      <path d="M3.5 3.75v16.5h17"/>
      <path d="M6.75 16.25 10.5 11l3.25 2.75 4.5-6.75"/>
      <circle cx="18.25" cy="7" r="1.5" fill="currentColor" stroke="none"/>
    SVG
    "trend_up" => <<~SVG,
      <path d="M3.5 17.5 10 11l3.5 3.5 7-7"/>
      <path d="M15.5 7.5h5v5"/>
    SVG
    "trend_down" => <<~SVG,
      <path d="M3.5 7.5 10 14l3.5-3.5 7 7"/>
      <path d="M15.5 16.5h5v-5"/>
    SVG
    "bars" => <<~SVG,
      <path d="M4.5 20.25V13.5"/>
      <path d="M9.5 20.25V4.75"/>
      <path d="M14.5 20.25v-9.5"/>
      <path d="M19.5 20.25V8"/>
    SVG
    "list" => <<~SVG,
      <path d="M4 6.5h16"/>
      <path d="M4 12h16"/>
      <path d="M4 17.5h10"/>
    SVG

    # ── Fantasy ───────────────────────────────────────────────────────
    "briefcase" => <<~SVG,
      <rect x="3" y="7.25" width="18" height="12.5" rx="2"/>
      <path d="M8.75 7.25V5.5A1.75 1.75 0 0 1 10.5 3.75h3a1.75 1.75 0 0 1 1.75 1.75v1.75"/>
      <path d="M3 12.5h18"/>
    SVG
    "store" => <<~SVG,
      <path d="M4.75 10.5v9.75h14.5V10.5"/>
      <path d="M2.75 10.5 4.75 4.5h14.5l2 6"/>
      <path d="M2.75 10.5a2.6 2.6 0 0 0 5.15 0 2.6 2.6 0 0 0 5.2 0 2.6 2.6 0 0 0 5.2 0"/>
      <path d="M9.25 20.25V15h5.5v5.25"/>
    SVG
    "coins" => <<~SVG,
      <ellipse cx="12" cy="6.75" rx="7.75" ry="3.25"/>
      <path d="M4.25 6.75v10.5c0 1.8 3.47 3.25 7.75 3.25s7.75-1.45 7.75-3.25V6.75"/>
      <path d="M4.25 12c0 1.8 3.47 3.25 7.75 3.25S19.75 13.8 19.75 12"/>
    SVG
    "card" => <<~SVG,
      <rect x="4.25" y="2.75" width="15.5" height="18.5" rx="2.25"/>
      <circle cx="12" cy="9.5" r="2.75"/>
      <path d="M7.5 18.25a4.5 4.5 0 0 1 9 0"/>
    SVG
    "versus" => <<~SVG,
      <path d="M8.5 5.75 3 12l5.5 6.25"/>
      <path d="M15.5 5.75 21 12l-5.5 6.25"/>
      <path d="M12 4.25v15.5"/>
    SVG
    "shield" => <<~SVG,
      <path d="M12 2.75 4.75 5.6v6.05c0 4.4 3 7.9 7.25 9.6 4.25-1.7 7.25-5.2 7.25-9.6V5.6z"/>
    SVG
    "star" => <<~SVG,
      <path d="M12 3.25l2.4 6.35 6.35 2.4-6.35 2.4-2.4 6.35-2.4-6.35L3.25 12l6.35-2.4z"/>
    SVG
    "bolt" => <<~SVG,
      <path d="M13.6 2.75 5.4 13.4h5.5l-.9 7.85 8.6-11.1h-5.75z"/>
    SVG

    # ── Structure / navigation ────────────────────────────────────────
    "book" => <<~SVG,
      <path d="M12 6.75S10 4.75 4 4.75v13.5c6 0 8 2 8 2s2-2 8-2V4.75c-6 0-8 2-8 2Z"/>
      <path d="M12 6.75v13.5"/>
    SVG
    "calendar" => <<~SVG,
      <rect x="3.5" y="5" width="17" height="15.75" rx="2"/>
      <path d="M3.5 10h17"/>
      <path d="M8 3v4M16 3v4"/>
    SVG
    "archive" => <<~SVG,
      <rect x="3" y="4" width="18" height="4.5" rx="1.25"/>
      <path d="M4.75 8.5v9.75A2.25 2.25 0 0 0 7 20.5h10a2.25 2.25 0 0 0 2.25-2.25V8.5"/>
      <path d="M10 12.25h4"/>
    SVG
    "search" => <<~SVG,
      <circle cx="10.75" cy="10.75" r="7"/>
      <path d="M15.9 15.9 21 21"/>
    SVG
    "user" => <<~SVG,
      <circle cx="12" cy="8" r="4.25"/>
      <path d="M4.5 20.25a7.5 7.5 0 0 1 15 0"/>
    SVG
    "gear" => <<~SVG,
      <circle cx="12" cy="12" r="3.25"/>
      <path d="M12 2.75v2.6M12 18.65v2.6M21.25 12h-2.6M5.35 12h-2.6M18.55 5.45l-1.85 1.85M7.3 16.7l-1.85 1.85M18.55 18.55 16.7 16.7M7.3 7.3 5.45 5.45"/>
    SVG

    # ── State ─────────────────────────────────────────────────────────
    "lock" => <<~SVG,
      <rect x="4.5" y="10.25" width="15" height="10.5" rx="2"/>
      <path d="M8 10.25V7.5a4 4 0 0 1 8 0v2.75"/>
    SVG
    "unlock" => <<~SVG,
      <rect x="4.5" y="10.25" width="15" height="10.5" rx="2"/>
      <path d="M8 10.25V7.5a4 4 0 0 1 7.35-2.2"/>
    SVG
    "check" => <<~SVG,
      <path d="M4.75 12.5 9.9 17.65 19.25 6.9"/>
    SVG
    "close" => <<~SVG,
      <path d="M6 6l12 12M18 6 6 18"/>
    SVG
    "plus" => <<~SVG,
      <path d="M12 4.75v14.5M4.75 12h14.5"/>
    SVG
    "minus" => <<~SVG,
      <path d="M4.75 12h14.5"/>
    SVG
    "info" => <<~SVG,
      <circle cx="12" cy="12" r="9.25"/>
      <path d="M12 11.25v5.25"/>
      <circle cx="12" cy="7.9" r="1.15" fill="currentColor" stroke="none"/>
    SVG
    "warning" => <<~SVG,
      <path d="M13.3 4.2a1.5 1.5 0 0 0-2.6 0L3.05 18.4a1.5 1.5 0 0 0 1.3 2.25h15.3a1.5 1.5 0 0 0 1.3-2.25z"/>
      <path d="M12 9.5v4.6"/>
      <circle cx="12" cy="17.5" r="1.15" fill="currentColor" stroke="none"/>
    SVG

    # ── Arrows ────────────────────────────────────────────────────────
    "arrow_right" => <<~SVG,
      <path d="M4.25 12h15"/>
      <path d="M13.5 6.25 19.25 12l-5.75 5.75"/>
    SVG
    "arrow_left" => <<~SVG,
      <path d="M19.75 12h-15"/>
      <path d="M10.5 6.25 4.75 12l5.75 5.75"/>
    SVG
    "chevron_right" => <<~SVG,
      <path d="M9.25 5.5 15.75 12l-6.5 6.5"/>
    SVG
    "chevron_down" => <<~SVG,
      <path d="M5.5 9.25 12 15.75l6.5-6.5"/>
    SVG
  }.freeze

  # Renders one of the icons above as inline SVG.
  #
  #   size:  number (px) or any CSS length string, e.g. "1em"
  #   class: extra classes, appended after the base .icon class
  #   label: sets role="img" + <title> for icons that carry meaning on their own.
  #          Omit it for decorative icons sitting next to a text label — those
  #          stay aria-hidden so screen readers don't read the label twice.
  def ui_icon(name, size: 16, label: nil, **options)
    body = ICON_PATHS[name.to_s]
    raise ArgumentError, "Unknown icon #{name.inspect}" if body.nil? && Rails.env.development?
    return "".html_safe if body.nil?

    dimension = size.is_a?(Numeric) ? size.to_s : size
    classes = ["icon", options.delete(:class)].compact.join(" ")

    inner = label.present? ? tag.title(label) + body.html_safe : body.html_safe

    content_tag :svg, inner, {
      class: classes,
      width: dimension,
      height: dimension,
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 1.75,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      role: label.present? ? "img" : nil,
      "aria-hidden": label.present? ? nil : "true",
      focusable: "false"
    }.compact.merge(options)
  end
end
