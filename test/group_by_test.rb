# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit'
require_relative 'helpers'

class GroupByTest < Minitest::Test

  Customer = Struct.new(:id, :name, :age)

  def test_group_by
    result = Struct.new(:age, :count)
    query = Query.new(Table.new(Customer, 'customers'))
                 .group_by {|c| c.age }
                 .aggregate { |grouped, _row| result.new(grouped, Aggregate.count) }
    expected = <<-EOF
select 
  customers.age as age, 
  count(*) as count 
from customers 
group by customers.age
EOF

    assert_content_equal(expected, generate_sql(query))
  end

  def test_multiple_group_bys
    result = Struct.new(:level, :count)
    result2 = Struct.new(:level, :total, :count_level)
    query = Query.new(Table.new(Customer, 'customers'))
                 .group_by {|c| c.age }
                 .aggregate { |grouped, _row| result.new(grouped, Aggregate.count) }
                 .group_by {|c| c.level }
                 .aggregate { |grouped, row| result2.new(grouped, Aggregate.sum(row.count), Aggregate.count)}

    expected = <<-EOF
with subquery0 as (
  select customers.age as level, count(*) as count from customers group by customers.age
)

select subquery0.level as level, sum(subquery0.count) as total, count(*) as count_level from subquery0 group by subquery0.level
EOF

    assert_content_equal(expected, generate_sql(query))
  end
end
