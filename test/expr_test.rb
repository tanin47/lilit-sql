# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit'

class ExprTest < Minitest::Test
  def test_equal
    result = expr do |row|
      row.name == 'test' and row.name == 10
    end
    row = Row.new([Column.new(:name, nil)], nil)
    assert_equal(
      Condition.new(
        Condition.new(row.name, :eq, Literal.new('test')),
        :and,
        Condition.new(row.name, :eq, Literal.new(10)),
      ),
      result.call(row)
    )
  end

  def test_global_context
    row = Row.new([Column.new(:name, nil)], nil)
    result = expr do
      row.name == nil
    end
    assert_equal(
      Condition.new(row.name, :eq, Literal.new(nil)),
      result.call
    )
  end

  def test_format_currency
    result = expr do |row|
      if row.currency in ['krw', 'jpy']
        row.amount
      else
        # row.amount * 0.01
        row.currency
      end
    end

    row = Row.new([Column.new(:currency, nil), Column.new(:amount, nil)], nil)
    assert_equal(
      nil,
      result.call(row)
    )
  end
end
