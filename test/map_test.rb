# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit_sql'
require_relative 'helpers'

class MapTest < Minitest::Spec
  Customer = Struct.new(:id, :name, :age)

  it 'maps' do
    result = Struct.new(:level, :name)
    query = Query.from(Table.new(Customer, 'customers'))
                 .where { |c| c.name == 'test' and c.age == 34 }
                 .order_by { |c| c.name.asc }
                 .offset(20)
                 .limit(100)
                 .map { |c| result.new(c.age, c.name) }
    expected = <<~EOF
      select
        customers.age as level,
        customers.name as name
      from customers
      where customers.name = 'test' and customers.age = 34
      order by customers.name asc
      offset 20
      limit 100
    EOF

    assert_content_equal(expected, generate_sql(query))
  end

  it 'maps multiple times' do
    result = Struct.new(:level, :name)
    result2 = Struct.new(:level2, :name2)
    query = Query.from(Table.new(Customer, 'customers'))
                 .where { |c| c.name == 'test' and c.age == 34 }
                 .map { |c| result.new(c.age, c.name) }
                 .where { |c| c.level == 10 }
                 .map { |c| result2.new(c.level, c.name) }

    expected = <<~EOF
      with subquery0 as (
        select
          customers.age as level,
          customers.name as name
        from customers
        where customers.name = 'test' and customers.age = 34
      )

      select
        subquery0.level as level2,
        subquery0.name as name2
      from subquery0
      where subquery0.level = 10
    EOF

    assert_content_equal(expected, generate_sql(query))
  end
end
