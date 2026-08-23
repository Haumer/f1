module ApplicationHelper

    # Deterministic hue derived from a stable string — used for the colored
    # initial chip on the fantasy leaderboard so each user has a recognizable,
    # consistent color without a stored preference.
    USER_CHIP_PALETTE = [
      "#e64848", "#e67e22", "#f39c12", "#27ae60", "#16a085",
      "#2980b9", "#8e44ad", "#c0392b", "#d35400", "#2ecc71",
      "#1abc9c", "#3498db", "#9b59b6", "#e74c3c"
    ].freeze

    def user_chip_color(username)
      return USER_CHIP_PALETTE.first if username.blank?
      USER_CHIP_PALETTE[username.bytes.sum % USER_CHIP_PALETTE.size]
    end

    def user_chip_initial(username)
      return "?" if username.blank?
      username.strip[0].to_s.upcase
    end

    def elo_tier(peak_elo)
        return nil unless peak_elo

        if peak_elo >= 2600 then { label: "Elite", css: "elite" }
        elsif peak_elo >= 2450 then { label: "World Class", css: "world-class" }
        elsif peak_elo >= 2300 then { label: "Strong", css: "strong" }
        elsif peak_elo >= 2100 then { label: "Average", css: "average" }
        else { label: "Developing", css: "developing" }
        end
    end

    def elo_link(value, **opts)
        return "—" if value.nil?
        link_to number_with_delimiter(value.round), elo_path,
            title: "What is Elo?", class: "elo-link #{opts[:class]}".strip, **opts.except(:class)
    end

    def finished?(status_type)
        return false if status_type.blank?
        status_type.downcase == "finished" || status_type.downcase.include?("lap")
    end

    def hex_to_rgb(hex)
        return "225, 6, 0" if hex.blank?
        hex = hex.delete("#")
        "#{hex[0..1].to_i(16)}, #{hex[2..3].to_i(16)}, #{hex[4..5].to_i(16)}"
    end

    def constructor_logo_or_name(constructor, size: "sm")
        return "" unless constructor
        if constructor.logo_url.present?
            tag.img(src: constructor.logo_url, alt: constructor.name, class: "constructor-logo-#{size}", loading: "lazy", onerror: "this.style.display='none';this.nextElementSibling&&(this.nextElementSibling.style.display='inline')") +
            tag.span(constructor.name, class: "constructor-name-fallback", style: "display:none")
        else
            tag.span(constructor.name, class: "constructor-name-fallback")
        end
    end

    def constructor_color(constructor)
        Constructor::COLORS[constructor&.constructor_ref&.to_sym] || "#6c757d"
    end

    def flag_image(driver_or_country, size: 24)
        country = driver_or_country.respond_to?(:country) ? driver_or_country.country : driver_or_country
        return "" unless country&.respond_to?(:two_letter_country_code)
        code = country.two_letter_country_code
        return "" if code.blank?
        tag.img(src: "https://flagsapi.com/#{code}/shiny/#{size}.png",
                alt: "", loading: "lazy", width: size, height: size,
                onerror: "this.style.display='none'")
    end

    # Inline SVG line chart for stock price history. `points` is an array of
    # [date, price]. Returns an html_safe SVG string, or nil if fewer than 2
    # points (a 1-point chart is just noise).
    def stock_price_sparkline(points, width: 480, height: 96, accent: "#00d26a")
        return nil if points.size < 2

        prices = points.map { |_d, p| p.to_f }
        lo, hi = prices.minmax
        range = (hi - lo).zero? ? 1.0 : (hi - lo)
        step_x = points.size > 1 ? (width.to_f / (points.size - 1)) : 0

        path = points.each_with_index.map do |(_, p), i|
            x = (i * step_x).round(1)
            # Invert Y so higher prices render higher in the chart
            y = (height - ((p.to_f - lo) / range) * height).round(1)
            "#{i.zero? ? 'M' : 'L'}#{x} #{y}"
        end.join(" ")

        # Closed area fill for under-the-line shading
        area = "#{path} L#{width} #{height} L0 #{height} Z"

        last_x = ((points.size - 1) * step_x).round(1)
        last_y = (height - ((prices.last - lo) / range) * height).round(1)

        svg = <<~SVG.html_safe
            <svg viewBox="0 0 #{width} #{height}" xmlns="http://www.w3.org/2000/svg" class="stock-sparkline" preserveAspectRatio="none">
              <path d="#{area}" fill="#{accent}" fill-opacity="0.08"/>
              <path d="#{path}" fill="none" stroke="#{accent}" stroke-width="1.5"/>
              <circle cx="#{last_x}" cy="#{last_y}" r="3" fill="#{accent}"/>
            </svg>
        SVG
        svg.html_safe
    end

    # Classify the crowd on a driver based on SeasonDriver.net_demand.
    # Positive net = more longs than shorts; negative = crowded short.
    # Thresholds picked for the early-season scale where positions count in tens.
    def short_interest_tag(net_demand)
        n = net_demand.to_i
        if n >= 20 then { label: "Crowded long",  css: "crowd-long",  arrow: "up" }
        elsif n >= 5 then { label: "Leaning long",  css: "crowd-lean-long",  arrow: "up" }
        elsif n <= -20 then { label: "Crowded short", css: "crowd-short", arrow: "down" }
        elsif n <= -5 then { label: "Leaning short", css: "crowd-lean-short", arrow: "down" }
        else { label: "Balanced", css: "crowd-balanced", arrow: nil }
        end
    end


    # Compact relative time for dense rows: "3m", "16h", "15d", "2mo".
    # `time_ago_in_words` returns things like "about 16 hours" and "28 days",
    # which overflow the leaderboard and recent-pick rows on a phone and get
    # cut mid-value.
    def compact_time_ago(time)
        return nil if time.blank?

        seconds = (Time.current - time).to_i
        return "now" if seconds < 60

        minutes = seconds / 60
        return "#{minutes}m" if minutes < 60

        hours = minutes / 60
        return "#{hours}h" if hours < 24

        days = hours / 24
        return "#{days}d" if days < 7
        return "#{days / 7}w" if days < 60

        months = days / 30
        months < 12 ? "#{months}mo" : "#{days / 365}y"
    end

end
