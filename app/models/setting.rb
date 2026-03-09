class Setting < ApplicationRecord
    validates :key, presence: true, uniqueness: true

    after_save :clear_cache
    after_destroy :clear_cache

    def self.get(key, default = nil)
        Rails.cache.fetch("setting:#{key}", expires_in: 5.minutes) do
            find_by(key: key)&.value
        end || default
    end

    def self.set(key, value)
        setting = find_or_initialize_by(key: key)
        setting.update!(value: value.to_s)
        Rails.cache.delete("setting:#{key}")
    end

    # Safe column names for dynamic Elo queries — prevents SQL injection
    SAFE_ELO_COLUMNS = {
        peak_elo: "peak_elo_v2",
        elo: "elo_v2",
        new_elo: "new_elo_v2",
        old_elo: "old_elo_v2",
        new_constructor_elo: "new_constructor_elo_v2",
        old_constructor_elo: "old_constructor_elo_v2",
    }.freeze

    def self.elo_column(type)
        SAFE_ELO_COLUMNS.fetch(type)
    end

    def self.badge_min_year
        get("badge_min_year", "1996").to_i
    end

    def self.fantasy_stock_market?
        get("fantasy_stock_market", "disabled") == "enabled"
    end

    def self.image_source
        get("image_source", "f1")
    end

    def self.use_wikipedia_images?
        image_source == "wikipedia"
    end

    def self.analytics_excluded_user_ids
        ids = get("analytics_excluded_users", "[]")
        JSON.parse(ids).map(&:to_i)
    rescue JSON::ParserError
        []
    end

    def self.analytics_exclude_user!(user_id)
        ids = analytics_excluded_user_ids
        ids << user_id.to_i unless ids.include?(user_id.to_i)
        set("analytics_excluded_users", ids.to_json)
    end

    def self.analytics_include_user!(user_id)
        ids = analytics_excluded_user_ids - [user_id.to_i]
        set("analytics_excluded_users", ids.to_json)
    end

    def self.simulated_date
        val = get("simulated_date")
        Date.parse(val) if val.present?
    rescue Date::Error
        nil
    end

    def self.effective_today
        simulated_date || Date.today
    end

    private

    def clear_cache
        Rails.cache.delete("setting:#{key}")
    end
end
