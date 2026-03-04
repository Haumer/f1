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

    def self.elo_version
        get("elo_version", "v1")
    end

    def self.use_elo_v2?
        elo_version == "v2"
    end

    # Safe column names for dynamic Elo queries — prevents SQL injection
    SAFE_ELO_COLUMNS = {
        peak_elo: { v1: "peak_elo", v2: "peak_elo_v2" }.freeze,
        elo: { v1: "elo", v2: "elo_v2" }.freeze,
        new_elo: { v1: "new_elo", v2: "new_elo_v2" }.freeze,
        old_elo: { v1: "old_elo", v2: "old_elo_v2" }.freeze,
        new_constructor_elo: { v1: "new_constructor_elo_v2", v2: "new_constructor_elo_v2" }.freeze,
        old_constructor_elo: { v1: "old_constructor_elo_v2", v2: "old_constructor_elo_v2" }.freeze,
    }.freeze

    def self.elo_column(type)
        version = use_elo_v2? ? :v2 : :v1
        SAFE_ELO_COLUMNS.fetch(type).fetch(version)
    end

    def self.badge_min_year
        get("badge_min_year", "1996").to_i
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
