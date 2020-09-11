module Spree
  class UniquePurchasesReport < Spree::Report
    DEFAULT_SORTABLE_ATTRIBUTE = :product_name
    HEADERS                    = { sku: :string, product_name: :string, sold_count: :integer, users: :integer }
    SEARCH_ATTRIBUTES          = { start_date: :orders_completed_from, end_date: :orders_completed_till, user_manage_contry_ids: :country, email_cont: :email }
    SORTABLE_ATTRIBUTES        = [:product_name, :sku, :sold_count, :users]

    deeplink product_name: { template: %Q{<a href="/admin/products/{%# o.product_slug %}" target="_blank">{%# o.product_name %}</a>} }

    class Result < Spree::Report::Result
      class Observation < Spree::Report::Observation
        observation_fields [:product_name, :product_slug, :sku, :sold_count, :users]

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
      user_count_sql = '(COUNT(DISTINCT(spree_orders.email)))'
        resource_scope
          .joins(:order)
          .joins(:variant)
          .joins(:product)
          .where(spree_orders: { state: 'complete', completed_at: reporting_period })
          .group('variant_id', 'spree_variants.sku', 'spree_products.slug', 'spree_products.name')
          .select(
            'spree_variants.sku   as sku',
            'spree_products.slug  as product_slug',
            'spree_products.name  as product_name',
            'SUM(quantity)        as sold_count',
            "#{ user_count_sql }  as users"
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
