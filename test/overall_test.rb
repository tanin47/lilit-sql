# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit'

class OverallTest < Minitest::Test

  Customer = Struct.new(:id, :name, :age)

  def test_simple
    result = Struct.new(:level, :name)
    query = Table.new(Customer, 'customers')
         .where {|c| c.col(:name).eq(Literal.new('test')).and(c.col(:age).eq(Literal.new(34)))}
         .map(result) {|c| result.new(c.col(:age), c.col(:name))}

    assert_equal("select age as level, name from customers where name = 'test' and age = 34", query.sql)
  end

  # def test_group_by
  #   result = Struct.new(:age, :count)
  #   query = Table.new(Customer, 'customers')
  #                .group_by {|c| c.age}
  #                .aggregate(result) { |c| result(c.age, count()) }
  #
  #   assert_equal("select age, count(*) as count from customers group by age", query.generate_sql)
  # end
end
