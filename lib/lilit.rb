# frozen_string_literal: true

class From
  attr_accessor :source
  attr_accessor :join_type
  attr_accessor :condition

  def initialize(source, join_type = nil, condition = nil)
    @source = source
    @join_type = join_type
    @condition = condition
  end

  def rows
    source.rows
  end
end

class GroupBy
  attr_accessor :query
  attr_accessor :key

  def initialize(query, key)
    @query = query
    @key = key
  end

  def aggregate(&blk)
    result = blk.call(Aggregate.new, @key, *@query.rows)

    @query.set_grouped_key(@key)
    @query.set_row(Row.new(result.class.members, @query, result))
  end
end

class Row
  attr_accessor :parent
  attr_accessor :columns

  def initialize(columns, parent, origins = [])
    @columns = columns.zip(origins).map do |col, origin|
      if col.is_a?(Symbol)
        Column.new(col, parent, origin)
      elsif col.is_a?(Column)
        col
      else
        raise NotImplementedError
      end
    end
  end

  def col(name)
    found = @columns.select {|c| c.name == name}.first

    raise ArgumentError.new("#{name} is not found in the columns: #{@columns.map {|c|c.name}.inspect}") if found.nil?

    found
  end

  def has?(name)
    @columns.any? {|c| c.name == name}
  end

  def decl_sql
    @columns.map {|c|c.decl_sql}.join(', ')
  end
end

class Column
  attr_accessor :name
  attr_accessor :parent
  attr_accessor :origin

  def initialize(name, parent, origin = nil)
    @name = name
    @parent = parent
    @origin = origin
  end

  def eq(other)
    Condition.new(self, "eq", other)
  end

  def ref_sql
    "#{@parent.subquery_name}.#{@name}"
  end

  def decl_sql
    s = ''
    if origin
      origin_sql = origin.ref_sql
      if origin_sql != @name.to_s
        s += "#{origin.ref_sql} as "
      end
    end
    s += @name.to_s
    s
  end
end

class Count < Column

  def initialize
    super(nil, nil, nil)
  end

  def ref_sql
    decl_sql
  end

  def decl_sql
    "count(*)"
  end
end

class Sum < Column

  def initialize(col)
    super(nil, nil, col)
  end

  def ref_sql
    decl_sql
  end

  def decl_sql
    "sum(#{@origin.ref_sql})"
  end
end

class Aggregate
  def count
    Count.new
  end

  def sum(col)
    Sum.new(col)
  end
end

class Literal
  attr_accessor :value

  def initialize(value)
    @value = value
  end

  def ref_sql
    decl_sql
  end

  def decl_sql
    if @value.is_a?(Integer)
      "#{value}"
    elsif @value.is_a?(String)
      "'#{@value}'"
    else
      raise NotImplementedError.new("Literal doesn't support render #{@value.class} (#{@value})")
    end
  end
end

class Condition

  attr_accessor :left
  attr_accessor :op
  attr_accessor :right

  def initialize(left, op, right)
    @left = left
    @op = op
    @right = right
  end

  def and(other)
    Condition.new(self, "and", other)
  end

  def sql
    if op == "and"
      "#{left.sql} and #{right.sql}"
    elsif op == "eq"
      "#{left.ref_sql} = #{right.ref_sql}"
    end
  end
end

class Table
  attr_accessor :table_name
  attr_accessor :rows

  def initialize(struct, table_name)
    @table_name = table_name
    @rows = [Row.new(struct.members, self)]
  end

  def subquery_name
    @table_name.to_s
  end
end

class Query
  attr_accessor :froms
  attr_accessor :is_vanilla

  def initialize(from)
    @froms = [From.new(from, nil)]
    @conditions = []
    @grouped_key = nil
    @subquery_name = nil
    @row = nil
    @is_vanilla = @froms.size == 1
  end

  def map(&blk)
    if @row
      return Query.new(self).map(&blk)
    end

    unvanilla
    result = blk.call(*get_from_rows)
    set_row(Row.new(result.class.members, self, result))
  end

  def set_grouped_key(grouped_key)
    @grouped_key = grouped_key
    self
  end

  def set_row(row)
    @row = row
    self
  end

  def rows
    if @row
      return [@row]
    end

    get_from_rows
  end

  def group_by(&blk)
    if @row
      return Query.new(self).group_by(&blk)
    end

    unvanilla
    result = blk.call(*get_from_rows)

    if result.is_a?(Column)
      GroupBy.new(self, result)
    else
      raise NotImplementedError
    end
  end

  def join(other, &blk)
    perform_join(:join, other, &blk)
  end

  def left_join(other, &blk)
    perform_join(:left_join, other, &blk)
  end

  def where(&blk)
    if @row
      return Query.new(self).where(&blk)
    end

    unvanilla
    condition = blk.call(*get_from_rows)
    @conditions.push(condition)
    self
  end

  def subquery_name=(value)
    @subquery_name = value
  end

  def subquery_name
    if @is_vanilla
      return @froms.first.source.subquery_name
    end

    if @subquery_name.nil?
      raise ArgumentError.new("The query #{self.inspect} doesn't have a subquery name")
    end

    @subquery_name
  end

  def sql
    s = "select "
    s += rows.map {|r| r.decl_sql}.join(', ')
    s += " from"

    @froms.each_with_index do |from, index|
      if index >= 1
        if from.join_type == :join
          s += " join"
        elsif from.join_type == :left_join
          s += " left join"
        else
          raise ArgumentError.new("The join type #{from.join_type} is not supoprted.")
        end
      end

      s += " #{from.source.subquery_name}"

      if from.condition
        s += " on #{from.condition.sql}"
      end
    end

    if @conditions.size > 0
      s += " where #{@conditions.map {|c| c.sql}.join(' and ')}"
    end

    if @grouped_key
      s += " group by #{@grouped_key.ref_sql}"
    end

    s
  end

  private
  def get_from_rows
    @froms.map {|f| f.rows}.flatten
  end

  def unvanilla
    @is_vanilla = false
  end

  def perform_join(join_type, other, &blk)
    if @row || @conditions.size > 0
      return Query.new(self).send(:perform_join, join_type, other, &blk)
    end

    unvanilla
    condition = blk.call(*(get_from_rows + other.rows))
    @froms.push(From.new(other, join_type, condition))

    self
  end

end

def generate_sql(query)
  queries = fill(query)
  last_query = queries.pop

  sql = ''

  if queries.size > 0
    sql += 'with '
  end

  queries.map.with_index do |query, index|
    if index > 0
      sql += ', '
    end
    query.subquery_name = "subquery#{index}"
    sql += "#{query.subquery_name} as (\n#{query.sql}\n)\n"
  end

  sql += last_query.sql

  sql
end

def fill(query)
  return [] if query.is_vanilla

  queries = []
  query.froms.each do |from|
    if from.source.is_a?(Query)
      subqueries = fill(from.source)
      subqueries.each do |subquery|
        queries.push(subquery)
      end
    end
  end
  queries.push(query)
  queries
end
