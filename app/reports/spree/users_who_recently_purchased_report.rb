module Spree
  class UsersWhoRecentlyPurchasedReport < Spree::Report
    DEFAULT_SORTABLE_ATTRIBUTE = :purchase_count
    DEFAULT_SORT_DIRECTION     = :desc
    HEADERS                    = { user_email: :string, purchase_count: :integer, last_purchase_date: :date, last_purchased_order_number: :string }
    SEARCH_ATTRIBUTES          = { start_date: :start_date, end_date: :end_date, email_cont: :email, user_manage_contry_ids: :country }
    SORTABLE_ATTRIBUTES        = [:user_email, :purchase_count, :last_purchase_date]

    def paginated?
      true
    end

    class Result < Spree::Report::Result
      class Observation < Spree::Report::Observation
        observation_fields [:user_email, :last_purchased_order_number, :last_purchase_date, :purchase_count]

        def last_purchase_date
          @last_purchase_date.to_date.strftime("%B %d, %Y")
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

    def record_count_query
      Spree::Report::QueryFragments.from_subquery(report_query).project(Arel.star.count)
    end

    def report_query
      ar_orders = Arel::Table.new(:spree_orders)
      results = Arel::Table.new(:results)
      Spree::Report::QueryFragments
        .from_subquery(all_orders_with_users)
        .join(ar_orders)
        .on(
          ar_orders[:email].eq(results[:user_email]).and(
            ar_orders[:completed_at].eq(results[:last_purchase_date])
          )
        )
        .project(
          "results.user_email         as user_email",
          "spree_orders.number        as last_purchased_order_number",
          "results.last_purchase_date as last_purchase_date",
          "results.purchased_count    as purchase_count"
        )
    end


    def paginated_report_query
      report_query
        .take(records_per_page)
        .skip(current_page)
    end

    private def all_orders_with_users
      resource_scope
        .where(spree_orders: { completed_at: reporting_period })
        .select(
          "spree_users.email             as user_email",
          "max(spree_orders.completed_at) as last_purchase_date",
          "count(spree_orders.email)      as purchased_count"
        )
        .group(
          "user_email"
        )
    end

    private def resource_scope
      scope = resource_scope_by_class(Spree::Order).joins(:user)
      if (search[:user_manage_contry_ids])
        scope = scope.where(spree_users: {country_id: search[:user_manage_contry_ids]})
      end
      if search[:email_cont].present?
        scope = scope
          .where(Spree::User.arel_table[:email].matches("%#{ search[:email_cont] }%"))
      end
      scope
    end
  end
end
