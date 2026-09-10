# A read-only debrief of the stored race. The expectation model is separate from
# the Elo ratings and never changes their calculation or fantasy settlement.
# Always use this race's snapshots: today's Driver#elo_v2 would leak future form
# into old reports. No requests, writes, or Elo replays happen when viewing it.
class RaceAnalysis
  Row = Struct.new(:result, :seed, keyword_init: true) do
    delegate :driver, :constructor, to: :result

    def display_position
      return "—" if result.classified? && !result.position_order.to_i.positive?

      result.display_position
    end

    def classified?
      result.classified? && result.position_order.to_i.positive?
    end

    def grid_change
      result.grid - result.position_order if classified? && result.grid.to_i.positive?
    end

    def elo_change
      before = result.old_elo_v2
      after = result.new_elo_v2
      after - before if before&.finite? && after&.finite?
    end
  end

  attr_reader :race, :rows

  def initialize(race:)
    @race = race
    results = race.race_results.includes(:driver, :constructor, :status).to_a
    @rows = results.sort_by { |result| [result.position_order || Float::INFINITY, result.driver_id] }
                   .map { |result| Row.new(result: result) }
    assign_seeds
  end

  def available?
    rows.any?
  end

  def seeded?
    rows.any? && rows.all? { |row| row.seed.present? }
  end

  def coverage
    @coverage ||= {
      results: rows.size,
      elo: rows.count { |row| row.elo_change },
      grid: rows.count { |row| row.result.grid.to_i.positive? },
      qualifying: qualifying_by_driver.size
    }
  end

  def expectations
    @expectations ||= RaceExpectations::Report.new(race: race, rows: rows, qualifying: qualifying_by_driver)
  end

  def highlights
    @highlights ||= begin
      cards = []
      rated = rows.select { |row| row.elo_change }
      gain = rated.select { |row| row.elo_change.positive? }.max_by(&:elo_change)
      loss = rated.select { |row| row.elo_change.negative? }.min_by(&:elo_change)
      recovery = rows.select { |row| row.grid_change&.positive? }.max_by(&:grid_change)

      if gain
        cards << { label: "Largest Elo gain", row: gain, value: gain.elo_change, unit: "Elo", tone: "positive",
                   detail: "#{gain.display_position} · #{status_description(gain)}. The largest increase among the stored, rated results." }
      end
      if loss
        cards << { label: "Largest Elo loss", row: loss, value: loss.elo_change, unit: "Elo", tone: "negative",
                   detail: "#{loss.display_position} · #{status_description(loss)}. A rating change, not a verdict on the driver's performance." }
      end
      if recovery
        cards << { label: "Largest grid-to-finish gain", row: recovery, value: recovery.grid_change, unit: "places", tone: "positive",
                   detail: "Started P#{recovery.result.grid}, finished #{recovery.display_position}. Net position change, not an overtaking count." }
      end
      cards
    end
  end

  def teammates
    @teammates ||= rows.group_by { |row| row.result.constructor_id }.filter_map do |_id, team_rows|
      # Old shared-drive and multi-car entries aren't a modern two-car duel.
      next unless team_rows.size == 2

      first, second = team_rows
      comparable = first.classified? && second.classified?
      {
        constructor: first.constructor, rows: team_rows,
        gap: comparable ? (first.result.position_order - second.result.position_order).abs : nil,
        qualifying: qualifying_comparison(first, second)
      }
    end
  end

  def championship
    @championship ||= begin
      previous = previous_round&.driver_standings&.index_by(&:driver_id) || {}
      race.driver_standings.includes(:driver).select { |standing| standing.position.to_i.positive? }
          .sort_by { |standing| [standing.position, standing.driver_id] }.first(5).map do |standing|
        before = previous[standing.driver_id]
        movement = before.position - standing.position if before&.position.to_i.positive?
        { standing: standing, movement: movement }
      end
    end
  end

  def previous_round
    return @previous_round if defined?(@previous_round)

    # Never compare an opening round to the previous season, or silently skip a
    # missing standings snapshot and describe several weekends as one race.
    @previous_round = race.season.races.where("round < ?", race.round).order(round: :desc).first
  end

  def fantasy
    @fantasy ||= begin
      scores = RacePick.where(race: race).where.not(score: nil)
      { players: scores.count, best: scores.maximum(:score), average: scores.average(:score)&.to_f }
    end
  end

  private

  def assign_seeds
    return if rows.size < 2
    return unless rows.all? { |row| row.result.old_elo_v2&.finite? }
    return unless rows.map { |row| row.result.driver_id }.uniq.size == rows.size

    # Ties take their rank range's midpoint. Ranking an equal-rated opening field
    # all first would misleadingly mark every non-winner as below its Elo order.
    rows.each do |row|
      ahead = rows.count { |other| other.result.old_elo_v2 > row.result.old_elo_v2 }
      tied = rows.count { |other| other.result.old_elo_v2 == row.result.old_elo_v2 }
      row.seed = 1 + ahead + (tied - 1) / 2.0
    end
  end

  def qualifying_by_driver
    @qualifying_by_driver ||= QualifyingResult.where(race: race, driver_id: rows.map { |row| row.result.driver_id })
      .where("position > 0")
      .index_by(&:driver_id)
  end

  def qualifying_comparison(first, second)
    left = qualifying_by_driver[first.result.driver_id]
    right = qualifying_by_driver[second.result.driver_id]
    return unless left && right

    # Q1 and Q3 may have different conditions: only compare a shared segment.
    %i[q3 q2 q1].each do |segment|
      a = lap_seconds(left.public_send(segment))
      b = lap_seconds(right.public_send(segment))
      next unless a && b

      return { segment: segment.to_s.upcase, gap: (a - b).abs.round(3), faster: a <= b ? first : second }
    end
    nil
  end

  def lap_seconds(value)
    match = /\A(?:(\d+):)?(\d{1,2}\.\d{1,3})\z/.match(value.to_s)
    return unless match && match[2].to_f < 60

    seconds = match[1].to_i * 60 + match[2].to_f
    seconds if seconds.positive?
  end

  def status_description(row)
    row.result.status&.status_type.presence || "Status unavailable"
  end
end
