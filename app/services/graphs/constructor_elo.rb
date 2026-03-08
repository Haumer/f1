class Graphs::ConstructorElo
  def initialize(constructors:)
    @constructors = constructors
    @constructor_ids = constructors.map(&:id)
    build_elo_history
  end

  def data
    series = @constructors.map do |constructor|
      color = Constructor::COLORS[constructor.constructor_ref.to_sym] || "#666"
      history = @elo_history[constructor.id] || []
      {
        data: history.map { |h| h[:elo]&.round },
        type: 'line',
        name: constructor.name,
        color: color,
        smooth: true,
        symbolSize: 0,
        lineStyle: { width: 2 },
        emphasis: { focus: 'series' },
      }
    end

    {
      backgroundColor: 'transparent',
      xAxis: {
        type: 'category',
        data: @race_labels,
        axisLabel: { show: false }
      },
      yAxis: {
        type: 'value',
        min: 1500,
      },
      series: series,
      height: "400px",
      legend: {
        type: 'scroll',
        bottom: 0,
      },
      tooltip: {
        trigger: 'axis',
      },
      dataZoom: [
        { type: 'slider', xAxisIndex: [0], filterMode: 'filter' }
      ],
    }
  end

  private

  def build_elo_history
    @elo_history = @constructors.each_with_object({}) { |c, h| h[c.id] = [] }
    @race_labels = []

    # Fetch all race_results for these constructors with stored V2 Elo snapshots,
    # grouped by race in chronological order
    results = RaceResult.joins(:race)
                        .where(constructor_id: @constructor_ids)
                        .where.not(new_constructor_elo_v2: nil)
                        .includes(race: :circuit)
                        .order("races.date ASC, races.round ASC")
                        .to_a

    # Group by race, one data point per race
    results.group_by(&:race_id).each do |_race_id, race_results|
      race = race_results.first.race
      label = "#{race.circuit&.circuit_ref} #{race.date.strftime('%Y')}"
      # Disambiguate double-headers at the same circuit in the same year
      label = "#{label} (R#{race.round})" if @race_labels.include?(label)
      @race_labels << label

      by_constructor = race_results.group_by(&:constructor_id)
      @constructors.each do |c|
        rrs = by_constructor[c.id]
        if rrs
          elo_val = rrs.first.new_constructor_elo_v2
          @elo_history[c.id] << { elo: elo_val, race: label }
        elsif @elo_history[c.id].any?
          # Carry forward last known value for continuity
          @elo_history[c.id] << { elo: @elo_history[c.id].last[:elo], race: label }
        else
          # Constructor hasn't started racing yet — pad with nil
          @elo_history[c.id] << { elo: nil, race: label }
        end
      end
    end
  end
end
