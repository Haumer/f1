class SeasonsController < ApplicationController
  include StandingsData

  def index
    all_seasons = Season.includes(:drivers, :races).sorted_by_year
    @all_years = all_seasons.map { |s| s.year.to_i }

    if params[:from_year].present?
      from = params[:from_year].to_i
      to = params[:to_year].present? ? params[:to_year].to_i : @all_years.first
      @from_year = from
      @to_year = to
      @filtered = true
      @seasons = all_seasons.select { |s| y = s.year.to_i; y >= from && y <= to }
    else
      @seasons = all_seasons
    end

    @champions_by_season = DriverStanding.where(season_end: true, position: 1)
                        .includes(:driver, race: :season)
                        .index_by { |ds| ds.race.season_id }
    @champion_colors = champion_colors_by_season(@seasons)
  end

  def show
    @season = Season.find_by!(year: params[:id])
    set_season_champion_accent(@season)
    set_current_champion_accent if @page_accent == DEFAULT_ACCENT

    Seasons::ShowPresenter.new(
      season: @season,
      standings_extras: build_standings_extras(@season)
    ).call.each { |k, v| instance_variable_set("@#{k}", v) }
  end
end
