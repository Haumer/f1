module RaceExpectations
  class Dataset
    def self.before(date)
      Race.where("date < ?", date).joins(:qualifying_results).distinct
          .includes(:qualifying_results, race_results: :status).order(:date, :id).filter_map do |race|
        event(race)
      end
    end

    def self.event(race)
      results = race.race_results.to_a
      size = results.size
      return if size < 2 || results.any? { |result| !result.old_elo_v2&.finite? }
      return unless results.map(&:driver_id).uniq.size == size

      qualifying = race.qualifying_results.index_by(&:driver_id)
      samples = results.filter_map do |result|
        position = qualifying[result.driver_id]&.position
        next unless position&.between?(1, size) && result.classified? && result.position_order&.between?(1, size)

        ahead = results.count { |other| other.old_elo_v2 > result.old_elo_v2 }
        tied = results.count { |other| other.old_elo_v2 == result.old_elo_v2 }
        {
          elo: (ahead + (tied - 1) / 2.0) / (size - 1),
          qualifying: (position - 1).to_f / (size - 1),
          finish: (result.position_order - 1).to_f / (size - 1),
          field_size: size
        }
      end
      { id: race.id, date: race.date, samples: samples } if samples.any?
    end
  end
end
