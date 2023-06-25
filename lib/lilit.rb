# frozen_string_literal: true

class GroupBy
  attr_accessor :table
  attr_accessor :key

  def initialize(table, key)
    @table = table
    @key = key
  end

  def aggregate(&blk)
    grouped_key = Row.new([key.name])
    result = blk.call(grouped_key, Aggregate.new)

    @table.set_grouped_key(grouped_key)
    @table.set_row(Row.new(result.class.members, result))
  end
end

class Row
  attr_accessor :columns

  def initialize(columns, origins = [])
    @columns = columns.zip(origins).map do |col, origin|
      if col.is_a?(Symbol)
        Column.new(col, origin)
      elsif col.is_a?(Column)
        col
      else
        raise NotImplementedError
      end
    end
  end

  def col(symbol)
    found = @columns.select {|c| c.name == symbol}.first

    raise ArgumentError.new("#{symbol} is not found in the colums: #{@columns.map {|c|c.name}.inspect}") if found.nil?

    found
  end

  def sql
    @columns.map {|c|c.sql}.join(', ')
  end
end

class Column
  attr_accessor :name
  attr_accessor :origin

  def initialize(name, origin = nil)
    @name = name
    @origin = origin
  end

  def eq(other)
    Condition.new(self, "eq", other)
  end

  def sql(render_as = true)
    s = ''
    if origin and render_as
      origin_sql = origin.sql(false)
      if origin_sql != @name.to_s
        s += "#{origin.sql(false)} as "
      end
    end
    s += @name.to_s
    s
  end
end

class Count < Column

  def initialize
    super(nil, nil)
  end

  def sql
    "count(*)"
  end
end

class Aggregate
  def count
    Count.new
  end
end

class Literal
  attr_accessor :value

  def initialize(value)
    @value = value
  end

  def sql(render_as = true)
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
      "#{left.sql(false)} = #{right.sql(false)}"
    end
  end
end

class Table
  attr_accessor :table_name
  attr_accessor :row

  def initialize(struct, table_name)
    @table_name = table_name
    @row = Row.new(struct.members)
  end

  def subquery_name
    @table_name.to_s
  end
end

class Query
  attr_accessor :from

  def initialize(from)
    @from = from
    @conditions = []
    @grouped_key = nil
    @subquery_name = nil
    @row = nil
  end

  def map(&blk)
    if @row
      return Query.new(self).map(&blk)
    end

    result = blk.call(@from.row)
    set_row(Row.new(result.class.members, result))
  end

  def set_grouped_key(grouped_key)
    @grouped_key = grouped_key
    self
  end

  def set_row(row)
    @row = row
    self
  end

  def row
    if @row
      return @row
    end

    @from.row
  end

  def group_by(&blk)
    if @row
      return Query.new(self).group_by(&blk)
    end

    result = blk.call(@from.row)

    if result.is_a?(Column)
      GroupBy.new(self, result)
    else
      raise NotImplementedError
    end
  end

  def where(&blk)
    if @row
      return Query.new(self).where(&blk)
    end

    condition = blk.call(@from.row)
    @conditions.push(condition)
    self
  end

  def subquery_name=(value)
    @subquery_name = value
  end

  def subquery_name
    if @subquery_name.nil?
      raise ArgumentError.new("The query #{self.inspect} doesn't have a subquery name")
    end

    @subquery_name
  end

  def sql
    s = "select "
    s += row.sql
    s += " from #{@from.subquery_name}"

    if @conditions.size > 0
      s += " where #{@conditions.map {|c| c.sql}.join(' and ')}"
    end

    if @grouped_key
      s += " group by #{@grouped_key.sql}"
    end

    s
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
  if query.from.is_a?(Query)
    queries = fill(query.from)
    queries.push(query)
    queries
  elsif query.from.is_a?(Table)
    [query]
  end
end
