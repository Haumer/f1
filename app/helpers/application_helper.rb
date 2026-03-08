module ApplicationHelper

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

end
