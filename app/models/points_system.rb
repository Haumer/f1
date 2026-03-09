class PointsSystem < ApplicationRecord
  belongs_to :season

  validates :season_id, uniqueness: true
  validates :race_points, presence: true

  # Known historical points systems
  HISTORICAL = {
    (1950..1959) => {
      race_points: { 1 => 8, 2 => 6, 3 => 4, 4 => 3, 5 => 2 },
      fastest_lap_point: 1, fastest_lap_eligible: 99,
      notes: "Fastest lap point awarded to any finisher. Shared drives allowed."
    },
    (1960..1960) => {
      race_points: { 1 => 8, 2 => 6, 3 => 4, 4 => 3, 5 => 2, 6 => 1 },
      fastest_lap_point: 0, fastest_lap_eligible: 0,
      notes: "Sixth place added. Only best 6 of 10 results counted."
    },
    (1961..1990) => {
      race_points: { 1 => 9, 2 => 6, 3 => 4, 4 => 3, 5 => 2, 6 => 1 },
      fastest_lap_point: 0, fastest_lap_eligible: 0,
      notes: "Win increased to 9 points. Drop-scores applied until 1990."
    },
    (1991..2002) => {
      race_points: { 1 => 10, 2 => 6, 3 => 4, 4 => 3, 5 => 2, 6 => 1 },
      fastest_lap_point: 0, fastest_lap_eligible: 0,
      notes: "Win increased to 10 points. All results counted."
    },
    (2003..2009) => {
      race_points: { 1 => 10, 2 => 8, 3 => 6, 4 => 5, 5 => 4, 6 => 3, 7 => 2, 8 => 1 },
      fastest_lap_point: 0, fastest_lap_eligible: 0,
      notes: "Top 8 score. Points gap between positions reduced."
    },
    (2010..2018) => {
      race_points: { 1 => 25, 2 => 18, 3 => 15, 4 => 12, 5 => 10, 6 => 8, 7 => 6, 8 => 4, 9 => 2, 10 => 1 },
      fastest_lap_point: 0, fastest_lap_eligible: 0,
      notes: "Top 10 score. Win worth 25 points."
    },
    (2019..2020) => {
      race_points: { 1 => 25, 2 => 18, 3 => 15, 4 => 12, 5 => 10, 6 => 8, 7 => 6, 8 => 4, 9 => 2, 10 => 1 },
      fastest_lap_point: 1, fastest_lap_eligible: 10,
      notes: "Fastest lap bonus point for drivers finishing in the top 10."
    },
    (2021..2022) => {
      race_points: { 1 => 25, 2 => 18, 3 => 15, 4 => 12, 5 => 10, 6 => 8, 7 => 6, 8 => 4, 9 => 2, 10 => 1 },
      sprint_points: { 1 => 3, 2 => 2, 3 => 1 },
      fastest_lap_point: 1, fastest_lap_eligible: 10,
      notes: "Sprint races introduced. Top 3 in sprint score points."
    },
    (2023..2024) => {
      race_points: { 1 => 25, 2 => 18, 3 => 15, 4 => 12, 5 => 10, 6 => 8, 7 => 6, 8 => 4, 9 => 2, 10 => 1 },
      sprint_points: { 1 => 8, 2 => 7, 3 => 6, 4 => 5, 5 => 4, 6 => 3, 7 => 2, 8 => 1 },
      fastest_lap_point: 1, fastest_lap_eligible: 10,
      notes: "Sprint scoring expanded to top 8."
    },
    (2025..2099) => {
      race_points: { 1 => 25, 2 => 18, 3 => 15, 4 => 12, 5 => 10, 6 => 8, 7 => 6, 8 => 4, 9 => 2, 10 => 1 },
      sprint_points: { 1 => 8, 2 => 7, 3 => 6, 4 => 5, 5 => 4, 6 => 3, 7 => 2, 8 => 1 },
      fastest_lap_point: 0, fastest_lap_eligible: 0,
      notes: "Fastest lap point removed. Sprint top 8 continues."
    },
  }.freeze

  def self.seed_all!
    Season.find_each do |season|
      year = season.year.to_i
      config = HISTORICAL.find { |range, _| range.cover?(year) }&.last
      next unless config

      find_or_initialize_by(season: season).update!(
        race_points: config[:race_points],
        sprint_points: config[:sprint_points],
        fastest_lap_point: config[:fastest_lap_point] || 0,
        fastest_lap_eligible: config[:fastest_lap_eligible] || 0,
        positions_scoring: config[:race_points].size,
        sprint_positions_scoring: config[:sprint_points]&.size || 0,
        notes: config[:notes]
      )
    end
  end

  # Compact display: "25-18-15-12-10-8-6-4-2-1"
  def race_points_display
    return "" unless race_points
    race_points.sort_by { |k, _| k.to_i }.map(&:last).join("-")
  end

  def sprint_points_display
    return nil unless sprint_points&.any?
    sprint_points.sort_by { |k, _| k.to_i }.map(&:last).join("-")
  end

  def has_fastest_lap?
    fastest_lap_point.to_i > 0
  end

  def has_sprint?
    sprint_points.present? && sprint_points.any?
  end
end
