# frozen_string_literal: true

require 'ruby2ruby'
require 'ruby_parser'
require 'sourcify'

class Expr
  def and(other)
    BinaryOperation.new(self, :and, other)
  end

  def eq(other)
    BinaryOperation.new(self, :'=', other)
  end

  def not
    UnaryOperation.new(:not, self)
  end

  def minus
    UnaryOperation.new(:-, self)
  end

  def plus
    UnaryOperation.new(:+, self)
  end

  def ne(other)
    BinaryOperation.new(self, :'!=', other)
  end

  def in(list)
    BinaryOperation.new(self, :in, list)
  end

  def *(other)
    BinaryOperation.new(self, :*, other)
  end

  def +(other)
    BinaryOperation.new(self, :+, other)
  end

  def >=(other)
    BinaryOperation.new(self, :'>=', other)
  end

  def <=(other)
    BinaryOperation.new(self, :<=, other)
  end

  def >(other)
    BinaryOperation.new(self, :'>', other)
  end

  def <(other)
    BinaryOperation.new(self, :<, other)
  end

  def asc
    OrderedByExpr.new(self, :asc)
  end

  def desc
    OrderedByExpr.new(self, :desc)
  end
end

class OrderedByExpr
  attr_accessor :expr, :direction

  def initialize(expr, direction = nil)
    @expr = expr
    @direction = direction
  end

  def sql
    s = @expr.ref_sql

    if @direction
      s += " #{direction}"
    end
  end
end

class UnaryOperation < Expr
  attr_accessor :op

  def initialize(op, value)
    @op = op
    @value = value
  end

  def ref_sql
    "#{@op} (#{@value.ref_sql})"
  end

  def ==(other)
    other.class == self.class && other.state == state
  end

  def state
    instance_variables.map { |variable| instance_variable_get variable }
  end
end

class BinaryOperation < Expr
  attr_accessor :left, :op, :right

  def initialize(left, op, right)
    @left = left
    @op = op
    @right = lit(right)
  end

  def ref_sql
    if @right.is_a?(Literal) && @right.value.nil?
      return (
        if @op == :'='
          "#{@left.ref_sql} is #{@right.ref_sql}"
        elsif @op == :!=
          "#{@left.ref_sql} is not #{@right.ref_sql}"
        else
          raise ArgumentError.new("Nil doesn't support the operator: #{@op}")
        end
      )
    end

    if @op == :in
      return "#{@left.ref_sql} in (#{@right.map(&:ref_sql).join(', ')})"
    end

    "#{@left.ref_sql} #{@op} #{@right.ref_sql}"
  end

  def ==(other)
    other.class == self.class && other.state == state
  end

  def state
    instance_variables.map { |variable| instance_variable_get variable }
  end
end

class From
  attr_accessor :source, :join_type, :condition

  def initialize(source, join_type = nil, condition = nil, alias_name = nil)
    @source = source
    @join_type = join_type
    @condition = condition
    @alias_name = alias_name
  end

  attr_writer :alias_name

  def raw_alias_name
    @alias_name
  end

  def alias_name
    @alias_name || @source.subquery_name
  end

  def rows
    source.rows
  end
end

class CrossJoinUnnest
  attr_accessor :from, :row, :ordinality

  def initialize(from, row, ordinality)
    @from = from
    @row = row
    @ordinality = ordinality
  end

  def rows
    [@row].map {|r| r.with_from(@from)}
  end

  def alias_name
    @from.source.table_name
  end
end

class GroupBy
  attr_accessor :query, :keys

  def initialize(query, keys)
    @query = query
    @keys = keys
  end

  def aggregate(&blk)
    result = expr(&blk).call(@keys, *@query.rows)

    Query.new(
      @query.froms,
      @query.conditions,
      @keys,
      @query.order_bys,
      Row.new(result.class.members, result)
    )
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

  def col(name)
    found = @columns.select { |c| c.name == name }.first

    raise ArgumentError, "#{name} is not found in the columns: #{@columns.map(&:name).inspect}" if found.nil?

    found
  end

  def with_from(from)
    Row.new(@columns.map { |c| c.with_from(from) })
  end

  def has?(name)
    @columns.any? { |c| c.name == name }
  end

  def decl_sql
    @columns.map(&:decl_sql).join(', ')
  end

  private

  def method_missing(symbol, *args)
    col(symbol)
  rescue ArgumentError
    super
  end

  def respond_to_missing?(method_name, include_private = false)
    !col(method_name).nil?
  rescue ArgumentError
    super
  end
end



class Column < Expr
  attr_accessor :name, :origin

  def initialize(name, origin = nil, from = nil)
    @name = name
    @origin = origin
    @from = from
  end

  def with_from(from)
    Column.new(@name, @origin, from)
  end

  def ref_sql
    "#{@from.alias_name}.#{@name}"
  end

  def decl_sql
    s = ''
    if origin
      origin_sql = if origin.is_a?(Proc)
                     origin.call.ref_sql
                   else
                     origin.ref_sql
                   end
      s += "#{origin_sql} as " if origin_sql != @name.to_s
    end
    s += @name.to_s
    s
  end

  def ==(other)
    other.class == self.class && other.state == state
  end

  def state
    instance_variables.map { |variable| instance_variable_get variable }
  end
end

class Count < Column
  def initialize
    super(nil)
  end

  def ref_sql
    decl_sql
  end

  def decl_sql
    'count(*)'
  end
end

class Sum < Column
  def initialize(col)
    super(nil, col)
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

class Literal < Expr
  attr_accessor :value

  def initialize(value)
    @value = value
  end

  def ref_sql
    decl_sql
  end

  def decl_sql
    if @value.nil?
      'null'
    elsif @value.is_a?(Integer) || @value.is_a?(Float)
      @value.to_s
    elsif @value.is_a?(String)
      "'#{@value}'"
    else
      raise NotImplementedError, "Literal doesn't support render #{@value.class} (#{@value})"
    end
  end

  def ==(other)
    other.class == self.class && other.state == state
  end

  def state
    instance_variables.map { |variable| instance_variable_get variable }
  end
end

def lit(value)
  return value if value.is_a?(Literal)

  if value.is_a?(String) || value.is_a?(Integer) || value.is_a?(Float) || value.nil?
    Literal.new(value)
  elsif value.is_a?(Array)
    value.map { |v| lit(v) }
  else
    value
  end
end

class Table
  attr_accessor :table_name, :rows

  def initialize(struct, table_name)
    @table_name = table_name
    @rows = [Row.new(struct.members)]
  end

  def subquery_name
    @table_name.to_s
  end
end

class Query
  attr_accessor :froms, :conditions, :grouped_keys, :order_bys, :row, :_limit, :_offset

  def initialize(froms, conditions = [], grouped_keys = [], order_bys = [], row = nil, limit = nil, offset = nil)
    @froms = froms + []
    @conditions = conditions + []
    @grouped_keys = grouped_keys + []
    @order_bys = order_bys + []
    @row = row
    @_limit = limit
    @_offset = offset
    @subquery_name = nil
  end

  def self.from(query)
    new([From.new(query)])
  end

  def is_vanilla
    @froms.size == 1 && @conditions.empty? && @grouped_keys.empty? && @row.nil?
  end

  def map(&blk)
    return Query.from(self).map(&blk) if @row

    result = expr(&blk).call(*get_from_rows)
    Query.new(
      @froms,
      @conditions,
      @grouped_keys,
      @order_bys,
      Row.new(result.class.members, result),
      @_limit,
      @_offset
    )
  end

  def has?(column_name)
    rows.any? { |r| r.has?(column_name) }
  end

  def rows
    return [@row] if @row

    get_from_rows
  end

  def order_by(&blk)
    return Query.from(self).order_by(&blk) if @row

    result = expr(&blk).call(*get_from_rows)

    if result.is_a?(OrderedByExpr)
      result = [result]
    elsif result.is_a?(Expr)
      result = OrderedByExpr.new(result)
    end

    Query.new(
      @froms,
      @conditions,
      @grouped_keys,
      @order_bys + result,
      @row,
      @_limit,
      @_offset
    )
  end

  def limit(number)
    @_limit = number
    self
  end

  def offset(number)
    @_offset = number
    self
  end

  def group_by(&blk)
    return Query.from(self).group_by(&blk) if @row

    result = expr(&blk).call(*get_from_rows)

    if result.is_a?(Column)
      GroupBy.new(self, [result])
    elsif result.is_a?(Array)
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

  def right_join(other, &blk)
    perform_join(:right_join, other, &blk)
  end

  def cross_join(other)
    perform_join(:cross_join, other)
  end

  def cross_join_unnest(ordinality: false, &blk)
    return Query.from(self).cross_join_unnest(ordinality, &blk) if @row || @conditions.size.positive? || @order_bys.size.positive? || @_limit || @_offset

    result = expr(&blk).call(*get_from_rows)
    row = Row.new(result.class.members, result)
    from = CrossJoinUnnest.new(From.new(Table.new(result.class, 't')), row, ordinality)
    Query.new(
      @froms + [from],
      @conditions,
      @grouped_keys,
    )
  end

  def where(&blk)
    return Query.from(self).where(&blk) if @row

    condition = expr(&blk).call(*get_from_rows)
    Query.new(
      @froms,
      @conditions + [condition],
      @grouped_keys,
      @order_bys,
      @row,
      @_limit,
      @_offset
    )
  end

  def subquery_name
    return @froms.first.source.subquery_name if is_vanilla

    raise ArgumentError, "The query #{inspect} doesn't have a subquery name" if @subquery_name.nil?

    @subquery_name
  end

  attr_writer :subquery_name

  def sql
    s = 'select '
    s += rows.map(&:decl_sql).join(', ')
    s += ' from'

    @froms.each_with_index do |from, index|
      if from.is_a?(From)
        if index >= 1
          if from.join_type == :join
            s += ' join'
          elsif from.join_type == :left_join
            s += ' left join'
          elsif from.join_type == :right_join
            s += ' right join'
          elsif from.join_type == :cross_join
            s += ' cross join'
          else
            raise ArgumentError, "The join type #{from.join_type} is not supoprted."
          end
        end

        s += " #{from.source.subquery_name}"

        s += " #{from.alias_name}" if from.source.subquery_name != from.alias_name

        s += " on #{from.condition.ref_sql}" if from.condition
      elsif from.is_a?(CrossJoinUnnest)
        origins, cols = from.rows.first.columns.map {|c| [c.origin.ref_sql, c.name]}.transpose
        s += " cross join unnest (#{origins.join(', ')})"
        if from.ordinality
          s += ' with ordinality'
          cols.push('ordinal')
        end
        s += " as #{from.from.source.table_name} (#{cols.join(', ')})"
      else
        raise ArgumentError.new("From doesn't support #{from.inspect}")
      end
    end

    s += " where #{@conditions.map(&:ref_sql).join(' and ')}" if @conditions.size.positive?

    s += " group by #{@grouped_keys.map(&:ref_sql).join(', ')}" if @grouped_keys.size.positive?

    s += " order by #{@order_bys.map(&:sql).join(', ')}" if @order_bys.size.positive?

    if @_offset
      s += " offset #{@_offset}"
    end

    if @_limit
      s += " limit #{@_limit}"
    end

    s
  end

  private

  def get_from_rows
    @froms.map { |f| f.rows.map { |r| r.with_from(f) } }.flatten
  end

  def get_next_alias
    alias_names = @froms.map(&:raw_alias_name).compact
    index = 0
    alias_names.sort.each do |name|
      index += 1 if name == "alias#{index}"
    end
    "alias#{index}"
  end

  def perform_join(join_type, other, &blk)
    return Query.from(self).send(:perform_join, join_type, other, &blk) if @row || @conditions.size.positive? || @order_bys.size.positive? || @_limit || @_offset

    alias_name = nil
    @froms.each do |from|
      if from.source == other
        alias_name = get_next_alias
        break
      end
    end

    other_from = From.new(other, join_type, nil, alias_name)
    if blk
      condition = expr(&blk).call(*(get_from_rows + other_from.rows.map { |r| r.with_from(other_from) }))
      other_from.condition = condition
    end

    Query.new(
      @froms + [other_from],
      @conditions,
      @grouped_keys,
      @order_bys,
      @row
    )
  end
end

class IfElse
  def initialize(cond, true_result, false_result)
    @condition = lit(cond)
    @true_result = lit(true_result)
    @false_result = lit(false_result)
  end

  def ref_sql
    "if(#{@condition.ref_sql}, #{@true_result.ref_sql}, #{@false_result.ref_sql})"
  end

  def decl_sql
    ref_sql
  end

  def ==(other)
    other.class == self.class && other.state == state
  end

  def state
    instance_variables.map { |variable| instance_variable_get variable }
  end
end

def ifElse(cond, true_result, false_result)
  IfElse.new(cond, true_result, false_result)
end

def generate_sql(query)
  queries = fill(query)
  last_query = queries.pop

  sql = ''

  sql += 'with ' if queries.size.positive?

  queries.map.with_index do |q, index|
    sql += ', ' if index.positive?
    q.subquery_name = "subquery#{index}"
    sql += "#{q.subquery_name} as (\n#{q.sql}\n)\n"
  end

  sql += last_query.sql

  sql
end

def fill(query)
  return [] if query.is_vanilla

  queries = []
  query.froms.each do |from|
    next if from.is_a?(CrossJoinUnnest)
    next unless from.source.is_a?(Query)

    subqueries = fill(from.source)
    subqueries.each do |subquery|
      queries.push(subquery)
    end
  end
  queries.push(query)
  queries.uniq
end

$ruby2ruby = Ruby2Ruby.new

def rewrite(parsed)
  parsed = parsed.map do |component|
    if component.is_a?(Sexp)
      rewrite(component)
    else
      component
    end
  end

  if parsed[0] == :call
    if parsed[2] == :==
      parsed[2] = :eq
    elsif parsed[2] == :!=
      parsed[2] = :ne
    elsif parsed[2] == :!
      parsed[2] = :not
    elsif parsed[2] == :-@
      parsed[2] = :minus
    elsif parsed[2] == :+@
      parsed[2] = :plus
    elsif parsed[2] == :nil?
      parsed = Sexp.new(
        :call,
        parsed[1],
        :eq,
        Sexp.new(:nil)
      )
    end
  elsif parsed[0] == :and
    parsed = Sexp.new(
      :call,
      parsed[1],
      :and,
      parsed[2]
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
      parsed[3]
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
