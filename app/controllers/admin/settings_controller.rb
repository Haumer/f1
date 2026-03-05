module Admin
  class SettingsController < BaseController
    def show
      @elo_version = Setting.elo_version
      @simulated_date = Setting.get("simulated_date")
      @badge_min_year = Setting.badge_min_year
      latest_season = Season.sorted_by_year.first
      @race_dates = latest_season&.races&.sorted&.includes(:circuit)&.map { |r| { round: r.round, date: r.date, circuit: r.circuit.name } } || []
    end

    def update
      if params[:elo_version].present?
        unless %w[v1 v2].include?(params[:elo_version])
          redirect_to admin_settings_path, alert: "Invalid Elo version."
          return
        end
        Setting.set("elo_version", params[:elo_version])
        redirect_to admin_settings_path, notice: "Elo version switched to #{params[:elo_version]}."
      elsif params[:simulated_date].present?
        Setting.set("simulated_date", params[:simulated_date])
        redirect_to admin_settings_path, notice: "Date override set to #{params[:simulated_date]}."
      elsif params[:clear_simulated_date].present?
        Setting.set("simulated_date", "")
        redirect_to admin_settings_path, notice: "Date override cleared."
      elsif params[:badge_min_year].present?
        Setting.set("badge_min_year", params[:badge_min_year])
        redirect_to admin_settings_path, notice: "Badge minimum year set to #{params[:badge_min_year]}."
      else
        redirect_to admin_settings_path, alert: "No changes made."
      end
    end
  end
end
