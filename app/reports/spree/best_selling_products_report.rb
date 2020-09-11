module Spree
  class BestSellingProductsReport < Spree::Report
    DEFAULT_SORTABLE_ATTRIBUTE = :sold_count
    DEFAULT_SORT_DIRECTION     = :desc
    HEADERS                    = { sku: :string, product_name: :string, sold_count: :integer, sold_sum: :integer }
    SEARCH_ATTRIBUTES          = { start_date: :orders_completed_from, end_date: :orders_completed_to, user_manage_contry_ids: :country, email_cont: :email }
    SORTABLE_ATTRIBUTES        = [:product_name, :sku, :sold_count, :sold_sum]

    deeplink product_name: { template: %Q{<a href="/admin/products/{%# o.product_slug %}" target="_blank">{%# o.product_name %}</a>} }

    class Result < Spree::Report::Result
      class Observation < Spree::Report::Observation
        observation_fields [:product_name, :product_slug, :sku, :sold_count, :sold_sum]

        def sku
          @sku.presence || @product_name
        end
      end

      def to_h
        result = super
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

    def report_query
      if Spree.version.to_f >= 3.3
        return query_with_inventory_unit_quantities
      else
        return query_without_inventory_unit_quantities
      end
    end

    private def search_name
      search[:name].present? ? "%#{ search[:name] }%" : '%'
    end

    private def query_with_inventory_unit_quantities
      resource_scope
        .joins(:order)
        .joins(:variant)
        .joins(:product)
        .joins(:inventory_units)
        .where(Spree::Product.arel_table[:name].matches(search_name))
        .where(spree_orders: { state: 'complete' })
        .where(spree_orders: { completed_at: reporting_period })
        .where.not(spree_inventory_units: { state: 'returned' })
        .group(:variant_id, :product_name, :product_slug, 'spree_variants.sku')
        .select(
          'spree_products.name        as product_name',
          'spree_products.slug        as product_slug',
          'spree_variants.sku         as sku',
          'sum(spree_inventory_units.quantity) as sold_count',
          'ROUND(spree_line_items.quantity * spree_line_items.price, 2) as sold_sum'
        )
    end

    private def query_without_inventory_unit_quantities
      resource_scope
        .joins(:order)
        .joins(:variant)
        .joins(:product)
        .joins(:inventory_units)
        .where(Spree::Product.arel_table[:name].matches(search_name))
        .where(spree_orders: { state: 'complete' })
        .where(spree_orders: { completed_at: reporting_period })
        .where.not(spree_inventory_units: { state: 'returned' })
        .group(:variant_id, :product_name, :product_slug, 'spree_variants.sku')
        .select(
          'spree_products.name        as product_name',
          'spree_products.slug        as product_slug',
          'spree_variants.sku         as sku',
          'count(spree_line_items.id) as sold_count',
          'ROUND(spree_line_items.quantity * spree_line_items.price, 2) as sold_sum'
        )
    end

    private def resource_scope
      scope = resource_scope_by_class(Spree::LineItem)
      if (search[:user_manage_contry_ids])
        scope = scope.joins(order: :user).where(spree_users: {country_id: search[:user_manage_contry_ids]})
      end
      if search[:email_cont].present?
        scope = scope.joins(order: :user)
          .where(Spree::User.arel_table[:email].matches("%#{ search[:email_cont] }%"))
      end
      scope
    end
  end
end
