module Spree
  class SalesPerformanceReport < Spree::Report
    # HEADERS             = { sale_price: :integer, cost_price: :integer, promotion_discount: :integer, profit_loss: :integer, profit_loss_percent: :integer }
    HEADERS             = { sale_price: :integer, sale_price_avg: :integer}
    SEARCH_ATTRIBUTES   = { start_date: :orders_created_from, end_date: :orders_created_till, user_manage_contry_ids: :country }
    SORTABLE_ATTRIBUTES = []

    class Result < Spree::Report::TimedResult
      charts ProfitLossChart #, ProfitLossPercentChart, SaleCostPriceChart

      class Observation < Spree::Report::TimedObservation
        observation_fields cost_price: 0, sale_price: 0, profit_loss: 0, profit_loss_percent: 0, promotion_discount: 0, sale_price_avg: 0

        def cost_price
          @cost_price.to_f
        end

        def sale_price
          @sale_price.to_f
        end

        def profit_loss
          @profit_loss.to_f
        end

        def profit_loss_percent
          return (profit_loss * 100 / cost_price).round(2) unless cost_price.zero?
          0.0
        end

        def promotion_discount
          @promotion_discount.to_f
        end

        def sale_price_avg
          @sale_price_avg.to_f
        end
      end

      def to_h
        result = super
        result[:totals] = {
          sum: report.total_sum,
          avg: report.total_avg
        }
        result[:user] = {
          manage_contries: user_manage_contries
        }
        result
      end

      private def user_manage_contries
        countries = if report.current_user.has_spree_role?('admin')
          Spree::Country.europe
        else
          report.current_user.manage_countries
        end
        countries.map{|x| {id: x.id, name: x.name} }
      end
    end

    def total_sum
      resource_scope.sum(:total).to_f.round(2)
    end

    def total_avg
      resource_scope.average(:total).to_f.round(2)
    end

    private def report_query
      Spree::Report::QueryFragments
        .from_union(order_with_line_items_grouped_by_time, promotions_grouped_by_time)
        .group(*time_scale_columns_to_s)
        .order(*time_scale_columns)
        .project(
          *time_scale_columns,
          'SUM(sale_price) as sale_price',
          'SUM(cost_price) as cost_price',
          'SUM(profit_loss) as profit_loss',
          'SUM(promotion_discount) as promotion_discount',
          'ROUND(AVG(sale_price_avg), 2) as sale_price_avg'
        )
    end

    private def promotions_grouped_by_time
      Spree::Report::QueryFragments
        .from_subquery(promotion_adjustments_with_time)
        .group(*time_scale_columns_to_s, 'sale_price', 'cost_price')
        .order(*time_scale_columns)
        .project(
          *time_scale_columns,
          '0 as sale_price',
          '0 as cost_price',
          'SUM(promotion_discount) * -1 as profit_loss',
          'SUM(promotion_discount) as promotion_discount',
          '0 as sale_price_avg'
        )
    end

    private def promotion_adjustments_with_time
      Spree::Adjustment.joins(:order)
        .promotion
        .where(spree_orders: { completed_at: reporting_period })
        .select(
          'abs(amount) as promotion_discount',
          *time_scale_selects('spree_adjustments')
        )
    end

    private def order_with_line_items_grouped_by_time
      order_with_line_items_ar = Arel::Table.new(:order_with_line_items)
      zero = Arel::Nodes.build_quoted(0.0)
      Spree::Report::QueryFragments
        .from_subquery(order_with_line_items, as: :order_with_line_items)
        .group(*time_scale_columns_to_s)
        .order(*time_scale_columns)
        .project(
          *time_scale_columns,
          Spree::Report::QueryFragments.if_null(Spree::Report::QueryFragments.sum(order_with_line_items_ar[:sale_price]), zero).as('sale_price'),
          Spree::Report::QueryFragments.if_null(Spree::Report::QueryFragments.sum(order_with_line_items_ar[:cost_price]), zero).as('cost_price'),
          Spree::Report::QueryFragments.if_null(Spree::Report::QueryFragments.sum(order_with_line_items_ar[:profit_loss]), zero).as('profit_loss'),
          '0 as promotion_discount',
          Spree::Report::QueryFragments.if_null(Spree::Report::QueryFragments.avg(order_with_line_items_ar[:sale_price]), zero).as('sale_price_avg')
        )
    end

    private def order_with_line_items
      line_item_ar = Spree::LineItem.arel_table
      resource_scope
        .joins(:line_items)
        .group('spree_orders.id', *time_scale_columns_to_s)
        .select(
          *time_scale_selects('spree_orders'),
          "spree_orders.total as sale_price",
          "SUM(#{ Spree::Report::QueryFragments.if_null(line_item_ar[:cost_price], line_item_ar[:price]).to_sql } * spree_line_items.quantity) as cost_price",
          "(spree_orders.item_total - SUM(#{ Spree::Report::QueryFragments.if_null(line_item_ar[:cost_price], line_item_ar[:price]).to_sql } * spree_line_items.quantity)) as profit_loss"
        )
    end

    private def resource_scope
      scope = resource_scope_by_class(Spree::Order)
        .where.not(completed_at: nil)
        .where(created_at: reporting_period)
      if (search[:user_manage_contry_ids])
        scope = scope.joins(:user).where(spree_users: {country_id: search[:user_manage_contry_ids]})
      end
      scope
    end
  end
end
