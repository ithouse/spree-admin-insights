class Spree::SalesPerformanceReport::ProfitLossChart
  def initialize(result)
    time_dim = result.time_dimension
    @time_series = result.observations.collect(&time_dim)
    @sale_price = result.observations.collect(&:sale_price)
    @sale_price_avg = result.observations.collect(&:sale_price_avg)
  end

  def to_h
    {
      id: 'profit-loss',
      json: {
        title: {
          useHTML: true,
          text: "<span class='chart-title'>Total</span><span class='fa fa-question-circle' data-toggle='tooltip' title='Track the total value'></span>"
        },
        xAxis: { categories: @time_series },
        yAxis: {
          title: { text: 'Value(€)' }
        },
        legend: {
          layout: 'vertical',
          align: 'right',
          verticalAlign: 'middle',
          borderWidth: 0
        },
        series: [
          {
            name: 'Total',
            tooltip: { valuePrefix: '€' },
            data: @sale_price
          },
          {
            name: 'Average',
            tooltip: { valuePrefix: '€' },
            data: @sale_price_avg
          }
        ]
      }
    }

  end
end
