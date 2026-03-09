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

    def tooltip_style
      {
        backgroundColor: "rgba(20, 20, 30, 0.95)",
        borderColor: "rgba(255, 255, 255, 0.12)",
        borderWidth: 1,
        textStyle: { color: "#e0e0e0", fontSize: 13 },
        confine: true,
        appendToBody: true,
      }
    end

    # Multi-series line tooltip: shows all drivers at a given race
    # Expects data points with `name` like "Driver - Circuit - Position - Elo"
    # or just "Driver" with a `value` for Elo
    def line_tooltip
      tooltip_style.merge(
        trigger: "axis",
        formatter: js_function(<<~JS)
          function(params) {
            if (!params || params.length === 0) return '';
            var header = '<div style="font-weight:600;margin-bottom:6px;border-bottom:1px solid rgba(255,255,255,0.15);padding-bottom:4px">' + params[0].axisValueLabel + '</div>';
            var rows = '';
            params.forEach(function(p) {
              if (p.value === '' || p.value == null) return;
              var name = p.data && p.data.name ? p.data.name : p.seriesName;
              var parts = name.split(' - ');
              var label = parts.length >= 3 ? parts.slice(0, -1).join(' — ') : p.seriesName;
              var elo = typeof p.value === 'number' ? p.value : (parts[parts.length - 1] || '');
              rows += '<div style="display:flex;justify-content:space-between;gap:12px;line-height:1.6">'
                + '<span>' + p.marker + ' ' + label + '</span>'
                + '<span style="font-weight:600;font-family:monospace">' + elo + '</span></div>';
            });
            return rows ? header + rows : '';
          }
        JS
      )
    end

    # Single-series line tooltip (for driver career page)
    # name format: "Circuit - Date - Position - Elo"
    def single_line_tooltip
      tooltip_style.merge(
        trigger: "axis",
        formatter: js_function(<<~JS)
          function(params) {
            if (!params || params.length === 0) return '';
            var p = params[0];
            if (p.value === '' || p.value == null) return '';
            var name = p.data && p.data.name ? p.data.name : '';
            var parts = name.split(' - ');
            if (parts.length >= 4) {
              return '<div style="font-weight:600;margin-bottom:4px">' + parts[0] + '</div>'
                + '<div style="color:rgba(255,255,255,0.6);font-size:12px;margin-bottom:4px">' + parts[1] + '</div>'
                + '<div style="display:flex;justify-content:space-between;gap:16px">'
                + '<span>Finished ' + parts[2] + '</span>'
                + '<span style="font-weight:600;font-family:monospace">' + parts[3] + ' Elo</span></div>';
            }
            return p.marker + ' ' + name;
          }
        JS
      )
    end

    # Ranking chart tooltip: shows position (P1, P2, etc.) sorted by position
    def ranking_tooltip
      tooltip_style.merge(
        trigger: "axis",
        formatter: js_function(<<~JS)
          function(params) {
            if (!params || params.length === 0) return '';
            var header = '<div style="font-weight:600;margin-bottom:6px;border-bottom:1px solid rgba(255,255,255,0.15);padding-bottom:4px">' + params[0].axisValueLabel + '</div>';
            var items = params.filter(function(p) { return p.value != null && p.value !== ''; });
            items.sort(function(a, b) { return a.value - b.value; });
            var rows = '';
            items.forEach(function(p) {
              rows += '<div style="display:flex;justify-content:space-between;gap:12px;line-height:1.6">'
                + '<span>' + p.marker + ' ' + p.seriesName + '</span>'
                + '<span style="font-weight:600;font-family:monospace">P' + p.value + '</span></div>';
            });
            return rows ? header + rows : '';
          }
        JS
      )
    end

    def bar_tooltip
      tooltip_style.merge(
        trigger: "axis",
        axisPointer: { type: "shadow" }
      )
    end

    def podium_point(race_result, elo_val, position, item_style)
      podium_label = { 1 => "Win", 2 => "P2", 3 => "P3" }[position]
      {
        coord: [race_x_label(race_result.race), elo_val],
        label: { show: false },
        value: "#{podium_label} — #{race_result.race.circuit.name}",
        symbol: "circle",
        itemStyle: item_style,
        symbolSize: 8,
      }
    end

    def js_function(code)
      RailsCharts::Javascript.new(code)
    end
  end
end
