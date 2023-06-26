# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit'
require_relative 'helpers'

class JoinTest < Minitest::Spec

  Customer = Struct.new(:id, :name)
  City = Struct.new(:customer_id, :name)
  Height = Struct.new(:customer_id, :height)


  it 'joins' do
    customers = Query.new(Table.new(Customer, 'customers'))
    cities = Query.new(Table.new(City, 'cities'))
    heights = Query.new(Table.new(Height, 'heights'))

    result = Struct.new(:customer_id, :name, :city, :height)

    query = customers
      .join(cities) {|customer, city| customer.id == city.customer_id}
      .left_join(heights) {|customer, _city, height| customer.id == height.customer_id}
      .map { |customer, city, height| result.new(customer.id, customer.name, city.name, height.height)}

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

  it 'performs cumulative sum' do
    mrr_change_struct = Struct.new(:year, :amount_change)
    result = Struct.new(:year, :mrr)

    mrr_changes = Query.new(Table.new(mrr_change_struct, 'mrr_changes'))
    query = mrr_changes
      .left_join(mrr_changes) {|main, prior| prior.year <= main.year}
      .group_by {|main, _prior| main.year}
      .aggregate {|groupeds, row| result.new(groupeds[0], Aggregate.sum(row.amount_change)) }

    expected = <<-EOF
select
  mrr_changes0.year as year,
  sum(mrr_changes1.amount_change) as mrr
from mrr_changes mrr_changes0
left join mrr_changes mrr_changes1
on mrr_changes1.year <= mrr_changes0.year
group by mrr_changes0.year
    EOF

    assert_content_equal(expected, generate_sql(query))
  end
end
