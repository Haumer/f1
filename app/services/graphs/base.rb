module Graphs
  module Base
    private

    def race_x_label(race)
      "#{race.circuit.circuit_ref} #{race.date.strftime("%b %d, %Y")}"
    end

    def ordinalize(n)
      return "#{n}th" if (11..13).include?(n % 100)
      case n % 10
      when 1 then "#{n}st"
      when 2 then "#{n}nd"
      when 3 then "#{n}rd"
      else "#{n}th"
      end
    end

    def data_zoom_slider(start: 0)
      [{ id: "dataZoomX", type: "slider", xAxisIndex: [0], filterMode: "filter" }.tap { |h| h[:start] = start; h[:end] = 100 if start > 0 }]
    end

    def line_tooltip
      { trigger: "axis", formatter: "{b}", position: [10, 10] }
    end

    def bar_tooltip
      { trigger: "axis", axisPointer: { type: "shadow" } }
    end
  end
end
