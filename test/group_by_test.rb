# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit_sql'
require_relative 'helpers'

class GroupByTest < Minitest::Spec
  Customer = Struct.new(:id, :name, :age)

  it 'groups by' do
    result = Struct.new(:age, :count)
    query = Query.from(Table.new(Customer, 'customers'))
                 .group_by { |c| c.age }
                 .aggregate { |keys, _row| result.new(keys[0], Aggregate.count) }
    expected = <<~EOF
      select#{' '}
        customers.age as age,#{' '}
        count(*) as count#{' '}
      from customers#{' '}
      group by customers.age
    EOF

    assert_content_equal(expected, generate_sql(query))
  end

  it 'groups by multiple times' do
    result = Struct.new(:level, :count)
    result2 = Struct.new(:level, :total, :count_level)
    query = Query.from(Table.new(Customer, 'customers'))
                 .group_by { |c| c.age }
                 .aggregate { |keys, _row| result.new(keys[0], Aggregate.count) }
                 .group_by { |c| c.level }
                 .aggregate { |keys, row| result2.new(keys[0], Aggregate.sum(row.count), Aggregate.count) }

    expected = <<~EOF
      with subquery0 as (
        select customers.age as level, count(*) as count from customers group by customers.age
      )

      select subquery0.level as level, sum(subquery0.count) as total, count(*) as count_level from subquery0 group by subquery0.level
    EOF

    assert_content_equal(expected, generate_sql(query))
  end

  it 'groups by multiple keys' do
    result = Struct.new(:age_bucket, :name, :count)
    query = Query.from(Table.new(Customer, 'customers'))
                 .group_by { |c| [c.age * 10, c.name] }
                 .aggregate { |keys, _row| result.new(keys[0], keys[1], Aggregate.count) }
    expected = <<~EOF
      select#{' '}
        customers.age * 10 as age_bucket,#{' '}
        customers.name as name,#{' '}
        count(*) as count#{' '}
      from customers#{' '}
      group by customers.age * 10, customers.name
    EOF

    assert_content_equal(expected, generate_sql(query))
  end
end
