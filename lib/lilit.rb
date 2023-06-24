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

    @table.row = Row.new(result.class.members, result)
    @table.grouped_key = grouped_key

    table
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

  def sql
    s = ''
    if origin
      origin_sql = origin.sql
      if origin_sql != @name.to_s
        s += "#{origin.sql} as "
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

  def sql
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
      "#{left.sql} = #{right.sql}"
    end
  end
end

class Table
  attr_accessor :struct
  attr_accessor :table_name
  attr_accessor :conditions
  attr_accessor :row
  attr_accessor :grouped_key

  def initialize(struct, table_name)
    @struct = struct
    @table_name = table_name
    @row = Row.new(struct.members)
    @conditions = []
  end

  def map(&blk)
    result = blk.call(@row)
    @row = Row.new(result.class.members, result)
    self
  end

  def where(&blk)
    condition = blk.call(@row)
    @conditions.push(condition)
    self
  end

  def group_by(&blk)
    result = blk.call(@row)

    if result.is_a?(Column)
      GroupBy.new(self, result)
    else
      raise NotImplementedError
    end
  end

  def sql
    s = "select "
    s += @row.sql
    s += " from #{@table_name}"

    if @conditions.size > 0
      s += " where #{@conditions.map {|c| c.sql}.join(' and ')}"
    end

    if @grouped_key
      s += " group by #{@grouped_key.sql}"
    end

    s
  end
end
