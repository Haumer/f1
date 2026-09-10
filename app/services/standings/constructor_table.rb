module Standings
  class ConstructorTable
    def initialize(season:, race: nil)
      @season = season
      @race = race || season.latest_race
    end

    def call
      return [] unless @race

      rows = official_standings? ? official_rows : calculated_rows
      decorate_with_elo(rows)
    end

    private

    def official_standings?
      # Imported historical races have authoritative constructor standings.
      # Races created by the live updater do not, and must be calculated from
      # their race and sprint results instead.
      @race.kaggle_id.present? && ConstructorStanding.where(race: @race).exists?
    end

    def official_rows
      finish_counts = finish_counts_by_constructor

      ConstructorStanding.where(race: @race).includes(:constructor).map do |standing|
        counts = finish_counts[standing.constructor_id]
        {
          constructor: standing.constructor,
          points: standing.points || 0,
          wins: standing.wins || counts[1],
          seconds: counts[2],
          thirds: counts[3],
          position: standing.position,
          source: :official
        }
      end.sort_by { |row| row[:position] || Float::INFINITY }
    end

    def calculated_rows
      results = RaceResult.all_result_types
                          .where(race_id: races_through_target.select(:id))
                          .includes(:constructor)
                          .to_a
      points = Hash.new(0)
      finish_counts = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      constructors = {}

      results.each do |result|
        constructors[result.constructor_id] ||= result.constructor
        points[result.constructor_id] += result.points || 0
        next unless result.result_type == "race" && result.position_order

        finish_counts[result.constructor_id][result.position_order] += 1
      end

      ordered_ids = constructors.keys.sort_by do |constructor_id|
        counts = finish_counts[constructor_id]
        [
          -points[constructor_id],
          *countback_values(counts),
          constructors[constructor_id].name
        ]
      end

      ordered_ids.each_with_index.map do |constructor_id, index|
        counts = finish_counts[constructor_id]
        {
          constructor: constructors[constructor_id],
          points: points[constructor_id],
          wins: counts[1],
          seconds: counts[2],
          thirds: counts[3],
          position: index + 1,
          source: :calculated
        }
      end
    end

    def races_through_target
      @season.races.where("round <= ?", @race.round)
    end

    def finish_counts_by_constructor
      RaceResult.where(race_id: races_through_target.select(:id), position_order: 1..20)
                .group(:constructor_id, :position_order)
                .count
                .each_with_object(Hash.new { |hash, key| hash[key] = Hash.new(0) }) do |((constructor_id, position), count), grouped|
        grouped[constructor_id][position] = count
      end
    end

    def countback_values(counts)
      (1..20).map { |position| -counts[position] }
    end

    def decorate_with_elo(rows)
      new_column = Setting.elo_column(:new_constructor_elo)
      old_column = Setting.elo_column(:old_constructor_elo)
      elo_by_constructor = RaceResult.where(race: @race)
                                     .where.not(new_column => nil)
                                     .group_by(&:constructor_id)

      rows.map do |row|
        result = elo_by_constructor[row[:constructor].id]&.first
        current_elo = result&.public_send(new_column)
        old_elo = result&.public_send(old_column)

        row.merge(
          elo: current_elo&.round || row[:constructor].display_elo&.round,
          peak_elo: row[:constructor].display_peak_elo&.round,
          elo_diff: current_elo && old_elo ? (current_elo - old_elo).round : nil
        )
      end
    end
  end
end
