# frozen_string_literal: true

require 'ruby2ruby'
require 'ruby_parser'
require 'sourcify'

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
    result = blk.call(@key, *@query.rows)

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

  private def method_missing(symbol, *args)
    begin
      col(symbol)
    rescue ArgumentError
      super
    end
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
    Expr.new(self, :eq, other)
  end

  def in(list)
    Expr.new(self, :in, list)
  end

  def *(other)
    Expr.new(self, :*, other)
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

  def ==(other)
    other.class == self.class && other.state == self.state
  end

  def state
    self.instance_variables.map { |variable| self.instance_variable_get variable }
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

module Aggregate
  def self.count
    Count.new
  end

  def self.sum(col)
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
    if @value.nil?
      "null"
    elsif @value.is_a?(Integer) || @value.is_a?(Float)
      "#{@value}"
    elsif @value.is_a?(String)
      "'#{@value}'"
    else
      raise NotImplementedError.new("Literal doesn't support render #{@value.class} (#{@value})")
    end
  end

  def ==(other)
    other.class == self.class && other.state == self.state
  end

  def state
    self.instance_variables.map { |variable| self.instance_variable_get variable }
  end
end

class Expr
  attr_accessor :left
  attr_accessor :op
  attr_accessor :right

  def initialize(left, op, right)
    @left = left
    @op = op
    @right = right
  end

  def and(other)
    Expr.new(self, :and, other)
  end

  def ref_sql
    if op == :and
      "#{left.ref_sql} and #{right.ref_sql}"
    elsif op == :eq
      if right.is_a?(Literal) && right.value.nil?
        "#{left.ref_sql} is #{right.ref_sql}"
      else
        "#{left.ref_sql} = #{right.ref_sql}"
      end
    elsif op == :ne
      if right.is_a?(Literal) && right.value.nil?
        "#{left.ref_sql} is not #{right.ref_sql}"
      else
        "#{left.ref_sql} != #{right.ref_sql}"
      end
    elsif op == :*
      "#{left.ref_sql} * #{right.ref_sql}"
    elsif op == :in
      "#{left.ref_sql} in (#{right.map {|r|r.ref_sql}.join(', ')})"
    end
  end

  def ==(other)
    other.class == self.class && other.state == self.state
  end

  def state
    self.instance_variables.map { |variable| self.instance_variable_get variable }
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

  def initialize(from)
    @froms = [From.new(from)]
    @conditions = []
    @grouped_key = nil
    @subquery_name = nil
    @row = nil
  end

  def is_vanilla
    @froms.size == 1 && @conditions.empty? && @grouped_key.nil? && @row.nil?
  end

  def map(&blk)
    if @row
      return Query.new(self).map(&blk)
    end

    result = expr(&blk).call(*get_from_rows)
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

  def has?(column_name)
    rows.any? {|r| r.has?(column_name)}
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

    result = expr(&blk).call(*get_from_rows)

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

    condition = expr(&blk).call(*get_from_rows)
    @conditions.push(condition)
    self
  end

  def subquery_name=(value)
    @subquery_name = value
  end

  def subquery_name
    if is_vanilla
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
        s += " on #{from.condition.ref_sql}"
      end
    end

    if @conditions.size > 0
      s += " where #{@conditions.map {|c| c.ref_sql}.join(' and ')}"
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

  def perform_join(join_type, other, &blk)
    if @row || @conditions.size > 0
      return Query.new(self).send(:perform_join, join_type, other, &blk)
    end

    condition = expr(&blk).call(*(get_from_rows + other.rows))
    @froms.push(From.new(other, join_type, condition))

    self
  end
end

class IfElse
  def initialize(cond, true_result, false_result)
    @condition = cond
    @true_result = true_result
    @false_result = false_result
  end

  def ref_sql
    "if(#{@condition.ref_sql}, #{@true_result.ref_sql}, #{@false_result.ref_sql})"
  end

  def decl_sql
    ref_sql
  end

  def ==(other)
    other.class == self.class && other.state == self.state
  end

  def state
    self.instance_variables.map { |variable| self.instance_variable_get variable }
  end
end

def ifElse(cond, true_result, false_result)
  IfElse.new(cond, true_result, false_result)
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

$ruby2ruby = Ruby2Ruby.new

def search_for_expr_block(parsed)
  # s(:iter, s(:call, nil, :expr)

  if parsed[0] == :iter && parsed[1][0] == :call && parsed[1][1].nil? && parsed[1][2] == :expr
    return parsed[3]
  end

  parsed.each do |component|
    if component.is_a?(Sexp)
      return search_for_expr_block(component)
    end
  end

  nil
end

def rewrite(parsed)
  parsed = parsed.map do |component|
    if component.is_a?(Sexp)
      rewrite(component)
    else
      component
    end
  end

  if parsed[0] == :call && parsed[2] == :==
    parsed[2] = :eq
  elsif parsed[0] == :and
    parsed = Sexp.new(
      :call,
      parsed[1],
      :and,
      parsed[2]
    )
  elsif parsed[0] == :str
    parsed = Sexp.new(
      :call,
      Sexp.new(:const, :Literal),
      :new,
      Sexp.new(:str, parsed[1])
    )
  elsif parsed[0] == :lit && (parsed[1].is_a?(Integer) || parsed[1].is_a?(Float))
    parsed = Sexp.new(
      :call,
      Sexp.new(:const, :Literal),
      :new,
      Sexp.new(:lit, parsed[1])
    )
  elsif parsed[0] == :case && parsed[2] && parsed[2][0] == :in
    parsed = Sexp.new(
      :call,
      parsed[1],
      :in,
      parsed[2][1]
    )
  elsif parsed[0] == :if
    parsed = Sexp.new(
      :call,
      nil,
      :ifElse,
      parsed[1],
      parsed[2],
      parsed[3],
    )
  elsif parsed[0] == :nil
    parsed = Sexp.new(
      :call,
      Sexp.new(:const, :Literal),
      :new,
      Sexp.new(:nil)
    )
  end

  parsed
end

def expr(&blk)
  parsed = blk.to_sexp

  parsed = rewrite(parsed)

  code = $ruby2ruby.process(parsed)
  eval(code, blk.binding)
end
