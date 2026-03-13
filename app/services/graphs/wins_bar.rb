class Graphs::WinsBar
  include Graphs::Base

  def initialize(drivers:, field:, label:)
    @drivers = drivers.first(20)
    @field = field
    @label = label
  end

  def data
    names = @drivers.map { |d| "#{d.forename.first}.#{d.surname}" }
    values = @drivers.map do |d|
      {
        value: d.send(@field),
        itemStyle: { color: d.color }
      }
    end

    {
      backgroundColor: 'transparent',
      yAxis: {
        type: 'category',
        data: names.reverse,
        axisLabel: { fontSize: 11, color: 'rgba(255,255,255,0.7)' }
      },
      xAxis: {
        type: 'value',
        minInterval: 1,
        axisLabel: { color: 'rgba(255,255,255,0.7)' }
      },
      series: [
        {
          name: @label,
          type: 'bar',
          data: values.reverse,
          label: {
            show: true,
            position: 'right',
            formatter: '{c}',
            fontSize: 11,
            fontWeight: 'bold',
            color: 'rgba(255,255,255,0.85)'
          },
          barWidth: '60%'
        }
      ],
      tooltip: bar_tooltip,
      grid: {
        left: '120px',
        right: '50px',
        top: '10px',
        bottom: '10px',
        containLabel: false
      },
      height: "#{[@drivers.size * 28, 300].max}px"
    }
  end
end
