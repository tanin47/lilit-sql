# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit'
require_relative 'helpers'

class JoinTest < Minitest::Test

  Customer = Struct.new(:id, :name)
  City = Struct.new(:customer_id, :name)
  Height = Struct.new(:customer_id, :height)

  def test_join
    customers = Query.new(Table.new(Customer, 'customers'))
    cities = Query.new(Table.new(City, 'cities'))
    heights = Query.new(Table.new(Height, 'heights'))

    result = Struct.new(:customer_id, :name, :city, :height)

    query = customers
      .join(cities) {|customer, city| customer.col(:id).eq(city.col(:customer_id))}
      .left_join(heights) {|customer, _city, height| customer.col(:id).eq(height.col(:customer_id))}
      .map { |customer, city, height| result.new(customer.col(:id), customer.col(:name), city.col(:name), height.col(:height))}

    expected = <<-EOF
select
  customers.id as customer_id,
  customers.name as name,
  cities.name as city,
  heights.height as height
from customers
join cities
on customers.id = cities.customer_id
left join heights 
on customers.id = heights.customer_id
    EOF

    assert_content_equal(expected, generate_sql(query))
  end
end
