class Graphs::ChampionTimeline
  include Graphs::Base

  ERA_COLORS = {
    "Pioneers"      => "rgba(255,215,0,0.15)",
    "Ground Effect" => "rgba(0,200,100,0.15)",
    "Modern"        => "rgba(50,130,240,0.15)",
    "Hybrid"        => "rgba(200,50,100,0.15)"
  }.freeze

  ERAS = {
    "Pioneers"      => 1950..1969,
    "Ground Effect" => 1970..1989,
    "Modern"        => 1990..2009,
    "Hybrid"        => 2010..2099
  }.freeze

  def initialize(reigns:)
    @reigns = reigns
  end

  # Treemap: eras → drivers → sized by titles
  def treemap_data
    return {} if @reigns.empty?

    era_children = ERAS.map do |era_name, era_range|
      era_reigns = @reigns.select { |r| era_range.cover?(r[:start_year]) }
      next nil if era_reigns.empty?

      # Group by driver within this era
      by_driver = era_reigns.group_by { |r| r[:driver].id }
      driver_children = by_driver.map do |_did, dreigns|
        driver = dreigns.first[:driver]
        titles = dreigns.sum { |r| r[:titles] }
        years = dreigns.flat_map { |r| (r[:start_year]..r[:end_year]).to_a }
        color = dreigns.first[:color]
        team = dreigns.map { |r| r[:constructor]&.name }.compact.uniq.join(", ")

        {
          name: "#{driver.forename.first}. #{driver.surname}",
          value: titles,
          itemStyle: {
            color: color,
            borderColor: 'rgba(0,0,0,0.4)',
            borderWidth: 2
          },
          fullName: driver.fullname,
          years: years.join(", "),
          team: team
        }
      end.sort_by { |d| -d[:value] }

      {
        name: era_name,
        itemStyle: {
          color: ERA_COLORS[era_name],
          borderColor: 'rgba(255,255,255,0.2)',
          borderWidth: 3
        },
        children: driver_children
      }
    end.compact

    {
      backgroundColor: 'transparent',
      series: [{
        type: 'treemap',
        data: era_children,
        width: '100%',
        height: '100%',
        roam: false,
        nodeClick: false,
        breadcrumb: { show: false },
        levels: [
          {
            # Era level
            itemStyle: {
              borderColor: 'rgba(255,255,255,0.25)',
              borderWidth: 3,
              gapWidth: 3
            },
            upperLabel: {
              show: true,
              height: 28,
              color: '#fff',
              fontSize: 13,
              fontWeight: 'bold',
              textShadowColor: 'rgba(0,0,0,0.6)',
              textShadowBlur: 3
            }
          },
          {
            # Driver level
            itemStyle: {
              borderColor: 'rgba(0,0,0,0.3)',
              borderWidth: 2,
              gapWidth: 1
            },
            label: {
              show: true,
              formatter: js_function(<<~JS),
                function(p) {
                  if (p.data.value >= 3) return p.data.name + '\\n' + p.data.value + 'x';
                  if (p.data.value >= 2) return p.data.name + ' ' + p.data.value + 'x';
                  return p.data.name;
                }
              JS
              color: '#fff',
              fontSize: 12,
              fontWeight: 'bold',
              textShadowColor: 'rgba(0,0,0,0.7)',
              textShadowBlur: 3
            }
          }
        ]
      }],
      tooltip: tooltip_style.merge(
        formatter: js_function(<<~JS)
          function(p) {
            if (!p.data || !p.data.fullName) {
              return '<div style="font-weight:600">' + p.name + '</div>';
            }
            return '<div style="font-weight:600;margin-bottom:4px">' + p.data.fullName + '</div>'
              + '<div style="margin-bottom:2px">' + p.data.value + (p.data.value === 1 ? ' title' : ' titles') + '</div>'
              + '<div style="color:rgba(255,255,255,0.6);font-size:12px">' + p.data.years + '</div>'
              + (p.data.team ? '<div style="color:rgba(255,255,255,0.5);font-size:11px;margin-top:2px">' + p.data.team + '</div>' : '');
          }
        JS
      ),
      height: '500px'
    }
  end
end
