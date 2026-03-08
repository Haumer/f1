module Admin
  class SettingsController < BaseController
    def show
      @simulated_date = Setting.get("simulated_date")
      @badge_min_year = Setting.badge_min_year
      @fantasy_stock_market = Setting.fantasy_stock_market?
      @accent_override = Setting.get("accent_constructor_override")
      @image_source = Setting.image_source
      latest_season = Season.sorted_by_year.first
      @race_dates = latest_season&.races&.sorted&.includes(:circuit)&.map { |r| { round: r.round, date: r.date, circuit: r.circuit.name } } || []
    end

    def update
      if params[:simulated_date].present?
        Setting.set("simulated_date", params[:simulated_date])
        redirect_to admin_settings_path, notice: "Date override set to #{params[:simulated_date]}."
      elsif params[:clear_simulated_date].present?
        Setting.set("simulated_date", "")
        redirect_to admin_settings_path, notice: "Date override cleared."
      elsif params[:badge_min_year].present?
        Setting.set("badge_min_year", params[:badge_min_year])
        redirect_to admin_settings_path, notice: "Badge minimum year set to #{params[:badge_min_year]}."
      elsif params.key?(:accent_constructor_override)
        value = params[:accent_constructor_override].presence || ""
        Setting.set("accent_constructor_override", value)
        Rails.cache.delete("current_champion_accent")
        label = value.present? ? value.titleize : "auto-detect"
        redirect_to admin_settings_path, notice: "Accent color set to #{label}."
      elsif params[:image_source].present?
        Setting.set("image_source", params[:image_source])
        redirect_to admin_settings_path, notice: "Image source set to #{params[:image_source]}."
      elsif params[:fantasy_stock_market].present?
        value = params[:fantasy_stock_market] == "enabled" ? "enabled" : "disabled"
        Setting.set("fantasy_stock_market", value)
        redirect_to admin_settings_path, notice: "Fantasy Stock Market #{value}."
      else
        redirect_to admin_settings_path, alert: "No changes made."
      end
    end
  end
end
