class Graphs::ConstructorElo
  def initialize(constructors:)
    @constructors = constructors
    @races = Race.joins(:race_results)
                 .where(race_results: { constructor_id: @constructors.map(&:id) })
                 .distinct.order(date: :asc).includes(:circuit)
    build_elo_history
  end

  def data
    series = @constructors.map do |constructor|
      color = Constructor::COLORS[constructor.constructor_ref.to_sym] || "#666"
      history = @elo_history[constructor.id] || []
      {
        data: history.map { |h| h[:elo].round },
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
      xAxis: {
        type: 'category',
        data: @race_labels,
        axisLabel: { show: false }
      },
      yAxis: {
        type: 'value',
        min: Setting.use_elo_v2? ? 1500 : 800,
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
    current_elo = @constructors.each_with_object({}) { |c, h| h[c.id] = 1000.0 }
    @race_labels = []

    @races.find_each do |race|
      results = race.race_results.where(constructor_id: @constructors.map(&:id)).to_a
      constructor_results = results.group_by(&:constructor_id)

      # Calculate constructor places for this race
      constructor_places = constructor_results.map do |cid, rrs|
        best = rrs.min_by { |rr| rr.position_order || 999 }
        [cid, best.position_order || 999]
      end

      # Calculate adjustments
      adjustments = Hash.new(0.0)
      constructor_places.combination(2) do |(c1, p1), (c2, p2)|
        r1 = current_elo[c1] || 1000.0
        r2 = current_elo[c2] || 1000.0
        expected = 1.0 / (1 + (10 ** ((r2 - r1) / 400.0)))
        actual = p1 < p2 ? 1.0 : (p1 == p2 ? 0.5 : 0.0)
        adj = 4.0 * (actual - expected)
        adjustments[c1] += adj
        adjustments[c2] -= adj
      end

      # Apply and record
      label = "#{race.circuit&.circuit_ref} #{race.date.strftime('%Y')}"
      @race_labels << label

      @constructors.each do |c|
        if adjustments.key?(c.id)
          current_elo[c.id] += adjustments[c.id]
        end
        @elo_history[c.id] << { elo: current_elo[c.id], race: label }
      end
    end
  end
end
