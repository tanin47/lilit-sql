# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit_sql'
require_relative 'helpers'

class ExprTest < Minitest::Spec
  before do
    @from = From.new(Table.new(Struct.new(:id), 'tables'))
  end

  it 'comparison' do
    result = expr do |row|
      row.name == 'test' &&
        row.name >= 10 &&
        row.name > 10 &&
        row.name <= 10 &&
        row.name < 10 &&
        row.name != 10 &&
        row.name.nil? &&
        row.name != nil
    end

    expected = <<-EOF
tables.name = 'test'
and tables.name >= 10
and tables.name > 10
and tables.name <= 10
and tables.name < 10
and tables.name != 10
and tables.name is null
and tables.name is not null
    EOF

    row = Row.new([:name], []).with_from(@from)
    assert_content_equal(
      expected,
      result.call(row).ref_sql
    )
  end

  it 'supports the not operation' do
    result = expr do |row|
      !row.name.nil?
    end

    row = Row.new([:name], []).with_from(@from)
    assert_equal(
      'not (tables.name is null)',
      result.call(row).ref_sql
    )
  end

  it 'supports the unary -' do
    result = expr do |row|
      (-row.amount + row.amount) == 10
    end

    row = Row.new([:amount], []).with_from(@from)
    assert_equal(
      '- (tables.amount) + tables.amount = 10',
      result.call(row).ref_sql
    )
  end

  it 'supports the unary +' do
    result = expr do |row|
      (+row.amount + row.amount) == 10
    end

    row = Row.new([:amount], []).with_from(@from)
    assert_equal(
      '+ (tables.amount) + tables.amount = 10',
      result.call(row).ref_sql
    )
  end
end
