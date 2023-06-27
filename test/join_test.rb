# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit_sql'
require_relative 'helpers'

class JoinTest < Minitest::Spec
  Customer = Struct.new(:id, :name)
  City = Struct.new(:customer_id, :name)
  Height = Struct.new(:customer_id, :height)

  it 'joins' do
    customers = Query.from(Table.new(Customer, 'customers'))
    cities = Query.from(Table.new(City, 'cities'))
    heights = Query.from(Table.new(Height, 'heights'))

    result = Struct.new(:customer_id, :name, :city, :height)

    query = customers
            .join(cities) { |customer, city| customer.id == city.customer_id }
            .left_join(heights) { |customer, _city, height| customer.id == height.customer_id }
            .map { |customer, city, height| result.new(customer.id, customer.name, city.name, height.height) }

    expected = <<~EOF
      select
        customers.id as customer_id,
        customers.name as name,
        cities.name as city,
        heights.height as height
      from customers
      join cities
      on customers.id = cities.customer_id
      left join heights#{' '}
      on customers.id = heights.customer_id
    EOF

    assert_content_equal(expected, generate_sql(query))
  end
end
