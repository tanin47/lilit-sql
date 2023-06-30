# frozen_string_literal: true
# typed: true

require 'ruby2ruby'
require 'ruby_parser'
require 'sourcify'
require 'sorbet-runtime'

extend T::Sig # rubocop:disable Style/MixinUsage

class Expr
  extend T::Sig

  sig {params(other: Expr).returns(Expr)}
  def and(other)
    BinaryOperation.new(self, :and, other)
  end

  sig {params(other: T.nilable(T.any(Expr, Integer, Float, String))).returns(Expr)}
  def eq(other)
    BinaryOperation.new(self, :'=', other)
  end

  sig {returns(Expr)}
  def not
    UnaryOperation.new(:not, self)
  end

  sig {returns(T.any(Expr, Integer, Float))}
  def minus
    UnaryOperation.new(:-, self)
  end

  sig {returns(T.any(Expr, Integer, Float))}
  def plus
    UnaryOperation.new(:+, self)
  end

  sig {params(other: T.nilable(T.any(Expr, Integer, Float, String))).returns(Expr)}
  def ne(other)
    BinaryOperation.new(self, :'!=', other)
  end

  sig {params(list: T::Array[Expr]).returns(Expr)}
  def in(list)
    BinaryOperation.new(self, :in, list)
  end

  sig {params(other: T.any(Expr, Integer, Float)).returns(Expr)}
  def *(other)
    BinaryOperation.new(self, :*, other)
  end

  sig {params(other: T.any(Expr, Integer, Float)).returns(Expr)}
  def +(other)
    BinaryOperation.new(self, :+, other)
  end

  sig {params(other: T.any(Expr, Integer, Float)).returns(Expr)}
  def >=(other)
    BinaryOperation.new(self, :'>=', other)
  end

  sig {params(other: T.any(Expr, Integer, Float)).returns(Expr)}
  def <=(other)
    BinaryOperation.new(self, :<=, other)
  end

  sig {params(other: T.any(Expr, Integer, Float)).returns(Expr)}
  def >(other)
    BinaryOperation.new(self, :>, other)
  end

  sig {params(other: T.any(Expr, Integer, Float)).returns(Expr)}
  def <(other)
    BinaryOperation.new(self, :<, other)
  end

  sig {returns(OrderedByExpr)}
  def asc
    OrderedByExpr.new(self, :asc)
  end

  sig {returns(OrderedByExpr)}
  def desc
    OrderedByExpr.new(self, :desc)
  end

  sig {returns(String)}
  def ref_sql
    raise NotImplementedError
  end
end

class OrderedByExpr
  extend T::Sig
  attr_accessor :expr, :direction

  sig {params(expr: Expr, direction: T.nilable(Symbol)).void}
  def initialize(expr, direction = nil)
    @expr = expr
    @direction = direction
  end

  sig {returns(String)}
  def sql
    s = @expr.ref_sql

    if @direction
      s += " #{@direction}"
    end

    s
  end
end

class UnaryOperation < Expr
  extend T::Sig
  attr_accessor :op

  sig {params(op: Symbol, value: Expr).void}
  def initialize(op, value)
    @op = op
    @value = value
    super()
  end

  sig {returns(String)}
  def ref_sql
    "#{@op} (#{@value.ref_sql})"
  end

  sig {params(other: T.untyped).returns(T::Boolean)}
  def ==(other)
    other.class == self.class && other.state == state
  end

  sig {returns(T::Array[T.untyped])}
  def state
    instance_variables.map { |variable| instance_variable_get variable }
  end
end

class BinaryOperation < Expr
  extend T::Sig
  attr_accessor :left, :op, :right

  sig do
    params(
      left: Expr,
      op: Symbol,
      right: T.nilable(T.any(Expr, T::Array[Expr], String, Integer, Float))
    ).void
  end
  def initialize(left, op, right)
    @left = left
    @op = op
    @right = lit(right)
    super()
  end

  sig {returns(String)}
  def ref_sql
    if @right.is_a?(Literal) && @right.value.nil?
      return (
        if @op == :'='
          "#{@left.ref_sql} is #{@right.ref_sql}"
        elsif @op == :!=
          "#{@left.ref_sql} is not #{@right.ref_sql}"
        else
          raise ArgumentError, "Nil doesn't support the operator: #{@op}"
        end
      )
    end

    if @op == :in && @right.is_a?(Array)
      return "#{@left.ref_sql} in (#{@right.map(&:ref_sql).join(', ')})"
    end

    "#{@left.ref_sql} #{@op} #{@right.ref_sql}"
  end

  sig {params(other: T.untyped).returns(T::Boolean)}
  def ==(other)
    other.class == self.class && other.state == state
  end

  sig {returns(T::Array[T.untyped])}
  def state
    instance_variables.map { |variable| instance_variable_get variable }
  end
end

class From
  extend T::Sig
  attr_accessor :source, :join_type, :condition

  sig do
    params(
      source: T.any(Query, Table),
      join_type: T.nilable(Symbol),
      condition: T.nilable(Expr),
      alias_name: T.nilable(String)
    ).void
  end
  def initialize(source, join_type = nil, condition = nil, alias_name = nil)
    @source = source
    @join_type = join_type
    @condition = condition
    @alias_name = alias_name
  end

  attr_writer :alias_name

  sig {returns(T.nilable(String))}
  def raw_alias_name
    @alias_name
  end

  sig {returns(String)}
  def alias_name
    @alias_name || @source.subquery_name
  end

  sig {returns(T::Array[Row])}
  def rows
    source.rows
  end
end

class CrossJoinUnnest
  extend T::Sig
  attr_accessor :from, :row, :ordinality

  sig {params(from: From, row: Row, ordinality: T::Boolean).void}
  def initialize(from, row, ordinality)
    @from = from
    @row = row
    @ordinality = ordinality
  end

  sig {returns(T::Array[Row])}
  def rows
    [@row].map { |r| r.with_from(@from) }
  end

  sig {returns(String)}
  def alias_name
    @from.source.table_name
  end
end

class GroupBy
  extend T::Sig

  attr_accessor :query, :keys

  sig {params(query: Query, keys: T::Array[Expr]).void}
  def initialize(query, keys)
    @query = query
    @keys = keys
  end

  sig {params(blk: Proc).returns(Query)}
  def aggregate(&blk)
    result = T.unsafe(expr(&blk)).call(@keys, *@query.rows)

    Query.new(
      @query.froms,
      @query.conditions,
      @keys,
      @query.order_bys,
      Row.new(result.class.members, result.to_a)
    )
  end
end

class Row
  extend T::Sig
  attr_accessor :columns

  sig do
    params(
      columns: T.any(T::Array[Symbol], T::Array[Column]),
      origins: T::Array[Expr]
    ).void
  end
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

  sig {params(name: Symbol).returns(Column)}
  def col(name)
    found = @columns.select { |c| c.name == name }.first

    raise ArgumentError, "#{name} is not found in the columns: #{@columns.map(&:name).inspect}" if found.nil?

    found
  end

  sig {params(from: T.any(From, CrossJoinUnnest)).returns(Row)}
  def with_from(from)
    Row.new(@columns.map { |c| c.with_from(from) })
  end

  sig {params(name: Symbol).returns(T::Boolean)}
  def has?(name)
    @columns.any? { |c| c.name == name }
  end

  sig {returns(String)}
  def decl_sql
    @columns.map(&:decl_sql).join(', ')
  end

  private

  sig {params(symbol: Symbol, args: T.untyped).returns(T.untyped)}
  def method_missing(symbol, *args)
    col(symbol)
  rescue ArgumentError
    super
  end

  sig {params(method_name: Symbol, include_private: T::Boolean).returns(T::Boolean)}
  def respond_to_missing?(method_name, include_private = false)
    !col(method_name).nil?
  rescue ArgumentError
    super
  end
end

class Column < Expr
  extend T::Sig

  attr_accessor :name, :origin

  sig do
    params(
      name: T.nilable(Symbol),
      origin: T.nilable(T.any(Expr, Proc)),
      from: T.nilable(T.any(From, CrossJoinUnnest))
    ).void
  end
  def initialize(name, origin = nil, from = nil)
    @name = name
    @origin = origin
    @from = from
    super()
  end

  sig {params(from: T.any(From, CrossJoinUnnest)).returns(Column)}
  def with_from(from)
    Column.new(@name, @origin, from)
  end

  sig {returns(String)}
  def ref_sql
    "#{T.must(@from).alias_name}.#{@name}"
  end

  sig {returns(String)}
  def decl_sql
    s = ''
    if @origin
      origin_sql = if @origin.is_a?(Proc)
                     @origin.call.ref_sql
                   else
                     @origin.ref_sql
                   end
      s += "#{origin_sql} as " if origin_sql != @name.to_s
    end
    s += @name.to_s
    s
  end

  sig {params(other: T.untyped).returns(T::Boolean)}
  def ==(other)
    other.class == self.class && other.state == state
  end

  sig {returns(T::Array[T.untyped])}
  def state
    instance_variables.map { |variable| instance_variable_get variable }
  end
end

class Count < Column
  extend T::Sig

  sig {void}
  def initialize
    super(nil)
  end

  sig {returns(String)}
  def ref_sql
    decl_sql
  end

  sig {returns(String)}
  def decl_sql
    'count(*)'
  end
end

class Sum < Column
  extend T::Sig

  sig {params(expr: Expr).void}
  def initialize(expr)
    super(nil, expr)
  end

  sig {returns(String)}
  def ref_sql
    decl_sql
  end

  sig {returns(String)}
  def decl_sql
    "sum(#{T.cast(@origin, Expr).ref_sql})"
  end
end

module Aggregate
  extend T::Sig

  sig {returns(Count)}
  def self.count
    Count.new
  end

  sig {params(expr: Expr).returns(Sum)}
  def self.sum(expr)
    Sum.new(expr)
  end
end

class Literal < Expr
  extend T::Sig

  attr_accessor :value

  sig {params(value: T.nilable(T.any(String, Integer, Float))).void}
  def initialize(value)
    @value = value
    super()
  end

  sig {returns(String)}
  def ref_sql
    decl_sql
  end

  sig {returns(String)}
  def decl_sql
    if @value.nil?
      'null'
    elsif @value.is_a?(Integer) || @value.is_a?(Float)
      @value.to_s
    elsif @value.is_a?(String)
      "'#{@value}'"
    else
      T.absurd(@value)
    end
  end

  sig {params(other: T.untyped).returns(T::Boolean)}
  def ==(other)
    other.class == self.class && other.state == state
  end

  sig {returns(T::Array[T.untyped])}
  def state
    instance_variables.map { |variable| instance_variable_get variable }
  end
end

sig {params(value: T.untyped).returns(T.untyped)}
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
  extend T::Sig
  attr_accessor :table_name, :rows

  sig do
    params(struct: T.class_of(Struct), table_name: String).void
  end
  def initialize(struct, table_name)
    @table_name = table_name
    @rows = [Row.new(struct.members)]
  end

  sig {returns(String)}
  def subquery_name
    @table_name.to_s
  end
end

class Query
  extend T::Sig
  attr_accessor :froms, :conditions, :grouped_keys, :order_bys, :row

  sig do
    params(
      froms: T::Array[From],
      conditions: T::Array[Expr],
      grouped_keys: T::Array[Expr],
      order_bys: T::Array[OrderedByExpr],
      row: T.nilable(Row),
      limit: T.nilable(Integer),
      offset: T.nilable(Integer)
    ).void
  end
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

  sig do
    params(query: T.any(Query, Table))
      .returns(Query)
  end
  def self.from(query)
    new([From.new(query)])
  end

  sig {returns(T::Boolean)}
  def is_vanilla
    T.must(@froms.size == 1 && @conditions.empty? && @grouped_keys.empty? && @row.nil?)
  end

  sig {params(blk: Proc).returns(Query)}
  def map(&blk)
    return Query.from(self).map(&blk) if @row

    result = T.unsafe(expr(&blk)).call(*get_from_rows)
    Query.new(
      @froms,
      @conditions,
      @grouped_keys,
      @order_bys,
      Row.new(result.class.members, result.to_a),
      @_limit,
      @_offset
    )
  end

  sig {params(column_name: Symbol).returns(T::Boolean)}
  def has?(column_name)
    rows.any? { |r| r.has?(column_name) }
  end

  sig {returns(T::Array[Row])}
  def rows
    return [@row] if @row

    get_from_rows
  end

  sig {params(blk: Proc).returns(Query)}
  def order_by(&blk)
    return Query.from(self).order_by(&blk) if @row

    result = T.unsafe(expr(&blk)).call(*get_from_rows)

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

  sig {params(number: Integer).returns(Query)}
  def limit(number)
    @_limit = number
    self
  end

  sig {params(number: Integer).returns(Query)}
  def offset(number)
    @_offset = number
    self
  end

  sig {params(blk: Proc).returns(GroupBy)}
  def group_by(&blk)
    return Query.from(self).group_by(&blk) if @row

    result = T.unsafe(expr(&blk)).call(*get_from_rows)

    if result.is_a?(Column)
      GroupBy.new(self, [result])
    elsif result.is_a?(Array)
      GroupBy.new(self, result)
    else
      raise NotImplementedError
    end
  end

  sig {params(other: Query, blk: Proc).returns(Query)}
  def join(other, &blk)
    perform_join(:join, other, &blk)
  end

  sig {params(other: Query, blk: Proc).returns(Query)}
  def left_join(other, &blk)
    perform_join(:left_join, other, &blk)
  end

  sig {params(other: Query, blk: Proc).returns(Query)}
  def right_join(other, &blk)
    perform_join(:right_join, other, &blk)
  end

  sig {params(other: Query).returns(Query)}
  def cross_join(other)
    perform_join(:cross_join, other)
  end

  sig {params(ordinality: T::Boolean, blk: Proc).returns(Query)}
  def cross_join_unnest(ordinality: false, &blk)
    return Query.from(self).cross_join_unnest(ordinality: ordinality, &blk) if @row || @conditions.size.positive? || @order_bys.size.positive? || @_limit || @_offset

    result = T.unsafe(expr(&blk)).call(*get_from_rows)
    row = Row.new(result.class.members, result.to_a)
    from = CrossJoinUnnest.new(From.new(Table.new(result.class, 't')), row, ordinality)
    Query.new(
      @froms + [from],
      @conditions,
      @grouped_keys
    )
  end

  sig {params(blk: Proc).returns(Query)}
  def where(&blk)
    return Query.from(self).where(&blk) if @row

    condition = T.unsafe(expr(&blk)).call(*get_from_rows)
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

  sig {returns(String)}
  def subquery_name
    return @froms.first.source.subquery_name if is_vanilla

    raise ArgumentError, "The query #{inspect} doesn't have a subquery name" if @subquery_name.nil?

    @subquery_name
  end

  attr_writer :subquery_name

  sig {returns(String)}
  def sql
    s = 'select '
    s += rows.map(&:decl_sql).join(', ')
    s += ' from'

    @froms.each_with_index do |from, index|
      if from.is_a?(From)
        if index >= 1
          case from.join_type
          when :join
            s += ' join'
          when :left_join
            s += ' left join'
          when :right_join
            s += ' right join'
          when :cross_join
            s += ' cross join'
          else
            raise ArgumentError, "The join type #{from.join_type} is not supoprted."
          end
        end

        s += " #{from.source.subquery_name}"

        s += " #{from.alias_name}" if from.source.subquery_name != from.alias_name

        s += " on #{from.condition.ref_sql}" if from.condition
      elsif from.is_a?(CrossJoinUnnest)
        origins, cols = T.must(from.rows.first).columns.map { |c| [c.origin.ref_sql, c.name] }.transpose
        s += " cross join unnest (#{origins.join(', ')})"
        if from.ordinality
          s += ' with ordinality'
          cols.push('ordinal')
        end
        s += " as #{from.from.source.table_name} (#{cols.join(', ')})"
      else
        raise ArgumentError, "From doesn't support #{from.inspect}"
      end
    end

    s += " where #{@conditions.map(&:ref_sql).join(' and ')}" if @conditions.size.positive?

    s += " group by #{@grouped_keys.map(&:ref_sql).join(', ')}" if @grouped_keys.size.positive?

    s += " order by #{@order_bys.map(&:sql).join(', ')}" if @order_bys.size.positive?

    s += " offset #{@_offset}" if @_offset

    s += " limit #{@_limit}" if @_limit

    s
  end

  private

  sig {returns(T::Array[Row])}
  def get_from_rows
    @froms.map { |f| f.rows.map { |r| r.with_from(f) } }.flatten
  end

  sig { returns(String) }
  def get_next_alias
    alias_names = @froms.map(&:raw_alias_name).compact
    index = 0
    alias_names.sort.each do |name|
      index += 1 if name == "alias#{index}"
    end
    "alias#{index}"
  end

  sig {params(join_type: Symbol, other: Query, blk: T.nilable(Proc)).returns(Query)}
  def perform_join(join_type, other, &blk)
    return Query.from(self).send(:perform_join, join_type, other, &blk) if @row || @conditions.size.positive? || @order_bys.size.positive? || @_limit || @_offset

    alias_name = T.let(nil, T.nilable(String))
    @froms.each do |from|
      if from.source == other
        alias_name = get_next_alias
        break
      end
    end

    other_from = From.new(other, join_type, nil, alias_name)
    if blk
      condition = T.unsafe(expr(&blk)).call(*(get_from_rows + other_from.rows.map { |r| r.with_from(other_from) }))
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

class IfElse < Expr
  extend T::Sig

  sig do
    params(
      cond: Expr,
      true_result: T.nilable(T.any(Expr, Integer, Float, String)),
      false_result: T.nilable(T.any(Expr, Integer, Float, String))
    ).void
  end
  def initialize(cond, true_result, false_result)
    @condition = lit(cond)
    @true_result = lit(true_result)
    @false_result = lit(false_result)
  end

  sig {returns(String)}
  def ref_sql
    "if(#{@condition.ref_sql}, #{@true_result.ref_sql}, #{@false_result.ref_sql})"
  end

  sig {returns(String)}
  def decl_sql
    ref_sql
  end

  sig {params(other: T.untyped).returns(T::Boolean)}
  def ==(other)
    other.class == self.class && other.state == state
  end

  sig {returns(T::Array[T.untyped])}
  def state
    instance_variables.map { |variable| instance_variable_get variable }
  end
end

sig do
  params(
    cond: Expr,
    true_result: T.nilable(T.any(Expr, Integer, Float, String)),
    false_result: T.nilable(T.any(Expr, Integer, Float, String))
  )
    .returns(IfElse)
end
def ifElse(cond, true_result, false_result)
  IfElse.new(cond, true_result, false_result)
end

sig do
  params(query: Query)
    .returns(String)
end
def generate_sql(query)
  queries = fill(query)
  last_query = T.must(queries.pop)

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

sig do
  params(query: Query)
    .returns(T::Array[Query])
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

sig do
  params(parsed: Sexp)
    .returns(Sexp)
end
def rewrite(parsed)
  parsed = parsed.map do |component|
    if component.is_a?(Sexp)
      rewrite(component)
    else
      component
    end
  end

  if parsed[0] == :call
    case parsed[2]
    when :==
      parsed[2] = :eq
    when :!=
      parsed[2] = :ne
    when :!
      parsed[2] = :not
    when :-@
      parsed[2] = :minus
    when :+@
      parsed[2] = :plus
    when :nil?
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

sig do
  params(blk: Proc)
    .returns(Proc)
end
def expr(&blk)
  parsed = T.unsafe(blk).to_sexp

  parsed = rewrite(parsed)

  code = $ruby2ruby.process(parsed)
  eval(code, blk.binding) # rubocop:disable Security/Eval
end
