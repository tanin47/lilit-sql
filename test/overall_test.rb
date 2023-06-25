# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit'
require_relative 'helpers'

class OverallTest < Minitest::Test

  Customer = Struct.new(:id, :name, :age)

  # def test_simple
  #   result = Struct.new(:level, :name)
  #   query = Query.new(Table.new(Customer, 'customers'))
  #        .where {|c| c.col(:name).eq(Literal.new('test')).and(c.col(:age).eq(Literal.new(34)))}
  #        .map {|c| result.new(c.col(:age), c.col(:name))}
  #
  #   assert_content_equal("select age as level, name from customers where name = 'test' and age = 34", generate_sql(query))
  # end

  def test_multiple_maps
    result = Struct.new(:level, :name)
    result2 = Struct.new(:level2, :name2)
    query = Query.new(Table.new(Customer, 'customers'))
                 .where {|c| c.col(:name).eq(Literal.new('test')).and(c.col(:age).eq(Literal.new(34)))}
                 .map {|c| result.new(c.col(:age), c.col(:name))}
                 .where {|c| c.col(:level).eq(Literal.new(10))}
                 .map {|c| result2.new(c.col(:level), c.col(:name))}

    expected = <<-EOF
with subquery0 as (
  select age as level, name from customers where name = 'test' and age = 34
)

select level as level2, name as name2 from subquery0 where level = 10
    EOF

    assert_content_equal(expected, generate_sql(query))
  end

  # def test_group_by
  #   result = Struct.new(:age, :count)
  #   query = Query.new(Table.new(Customer, 'customers'))
  #                .group_by {|c| c.col(:age) }
  #                .aggregate { |c, agg| result.new(c.col(:age), agg.count) }
  #
  #   assert_content_equal("select age, count(*) as count from customers group by age", generate_sql(query))
  # end
end
