module Spree::Report::QueryFragments
  def self.from_subquery(subquery, as: 'results')
    if Spree.version.to_f < 3.2
      Arel::SelectManager.new(Arel::Table.engine, Arel.sql("(#{subquery.to_sql}) as #{ as }"))
    else
      Arel::SelectManager.new(Arel.sql("(#{subquery.to_sql}) as #{ as }"))
    end
  end

  def self.from_join(subquery1, subquery2, join_expr)
    if Spree.version.to_f < 3.2
      Arel::SelectManager.new(Arel::Table.engine, Arel.sql("((#{ subquery1.to_sql }) as q1 JOIN (#{ subquery2.to_sql }) as q2 ON #{ join_expr })"))
    else
      Arel::SelectManager.new(Arel.sql("((#{ subquery1.to_sql }) as q1 JOIN (#{ subquery2.to_sql }) as q2 ON #{ join_expr })"))
    end
  end

  def self.from_union(subquery1, subquery2, *subqueries, as: 'results')
    query_sql = "(#{ subquery1.to_sql }) UNION (#{ subquery2.to_sql })"
    subqueries.each do |subquery|
      query_sql += " UNION (#{ subquery.to_sql })"
    end
    if Spree.version.to_f < 3.2
      Arel::SelectManager.new(Arel::Table.engine, Arel.sql("( #{ query_sql }) as #{ as }"))
    else
      Arel::SelectManager.new(Arel.sql("( #{ query_sql }) as #{ as }"))
    end
  end

  def self.year(column, as='year')
    extract_from_date(:year, column, as)
  end

  def self.month(column, as='month')
    extract_from_date(:month, column, as)
  end

  def self.week(column, as='week')
    extract_from_date(:week, column, as)
  end

  def self.day(column, as='day')
    extract_from_date(:day, column, as)
  end

  def self.hour(column, as='hour')
    extract_from_date(:hour, column, as)
  end

  def self.extract_from_date(part, column, as)
    "EXTRACT(#{ part } from #{ column }) AS #{ as }"
  end

  def self.if_null(val, default_val)
    Arel::Nodes::NamedFunction.new('COALESCE', [val, default_val])
  end

  def self.sum(node)
    Arel::Nodes::NamedFunction.new('SUM', [node])
  end

  def self.avg(node)
    Arel::Nodes::NamedFunction.new('AVG', [node])
  end
end
