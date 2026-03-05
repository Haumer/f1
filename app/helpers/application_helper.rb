module ApplicationHelper

    def elo_tier(peak_elo)
        return nil unless peak_elo

        if Setting.use_elo_v2?
            if peak_elo >= 2600 then { label: "Elite", css: "elite" }
            elsif peak_elo >= 2450 then { label: "World Class", css: "world-class" }
            elsif peak_elo >= 2300 then { label: "Strong", css: "strong" }
            elsif peak_elo >= 2100 then { label: "Average", css: "average" }
            else { label: "Developing", css: "developing" }
            end
        else
            if peak_elo >= 1500 then { label: "Elite", css: "elite" }
            elsif peak_elo >= 1400 then { label: "World Class", css: "world-class" }
            elsif peak_elo >= 1300 then { label: "Strong", css: "strong" }
            elsif peak_elo >= 1200 then { label: "Average", css: "average" }
            else { label: "Developing", css: "developing" }
            end
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

end
