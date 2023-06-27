# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit_sql'
require_relative 'helpers'

class ExprTest < Minitest::Spec

  before do
    @from = From.new(Table.new(Struct.new(:id), 'tables'))
  end

  it 'eq' do
    result = expr do |row|
      row.name == 'test' and row.name == 10
    end
    row = Row.new([:name], []).with_from(@from)
    assert_equal(
      "tables.name = 'test' and tables.name = 10",
      result.call(row).ref_sql
    )
  end

  it 'lte' do
    result = expr do |row|
      row.name <= 10
    end
    row = Row.new([:name], []).with_from(@from)
    assert_equal(
      "tables.name <= 10",
      result.call(row).ref_sql
    )
  end

  it 'reads from binding' do
    row = Row.new([:name], []).with_from(@from)
    result = expr do
      row.name == nil
    end
    assert_equal(
      "tables.name is null",
      result.call.ref_sql
    )
  end

  it 'format currency' do
    result = expr do |row|
      if row.currency in ['krw', 'jpy']
        row.amount
      else
        row.amount * 0.01
      end
    end

    row = Row.new([:currency, :amount], []).with_from(@from)
    assert_content_equal(
      "if(tables.currency in ('krw', 'jpy'), tables.amount, tables.amount * 0.01)",
      result.call(row).ref_sql
    )
  end
end
