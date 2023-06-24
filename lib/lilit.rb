# frozen_string_literal: true

module Query
  def where(&blk)
    self
  end

  def group_by
    self
  end

  def map(struct, &blk)
    self
  end

  def sql

  end
end

class GroupBy
  def aggregate(struct, &blk)

  end
end

class Row
  attr_accessor :columns

  def initialize(columns, origins = [])
    @columns = columns.zip(origins).map do |name, origin|
      Column.new(name, origin)
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
    if origin && origin.name != @name
      s += "#{origin.name} as "
    end
    s += @name.to_s
    s
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
  include Query

  attr_accessor :struct
  attr_accessor :table_name
  attr_accessor :conditions

  def initialize(struct, table_name)
    @struct = struct
    @table_name = table_name
    @row = Row.new(struct.members)
    @conditions = []
  end

  def map(struct, &blk)
    result = blk.call(@row)
    @row = Row.new(result.class.members, result)
    self
  end

  def where(&blk)
    condition = blk.call(@row)
    @conditions.push(condition)
    self
  end

  def sql
    s = "select "
    s += @row.sql
    s += " from #{@table_name}"

    if @conditions.size > 0
      s += " where #{@conditions.map {|c| c.sql}.join(' and ')}"
    end
    s
  end
end
