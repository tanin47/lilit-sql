# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit_sql'
require_relative 'helpers'

class WaterfallTest < Minitest::Spec
  Entry = Struct.new(:person, :year, :amount)

  def generate(start_year, end_year)
    cols = [:person] + (start_year..end_year).map { |y| "year_#{y}".to_sym }.to_a
    row = Struct.new(*cols)
    Query.from(Table.new(Entry, 'entries'))
         .where { |entry| lit(start_year) <= entry.year and entry.year <= end_year }
         .group_by { |entry| [entry.person, entry.year] }
         .aggregate { |keys, entry| Entry.new(keys[0], keys[1], Aggregate.sum(entry.amount)) }
         .group_by { |entry| entry.person }
         .aggregate do |keys, entry|
           values = [keys[0]] + (start_year..end_year).to_a.map do |year|
             if entry.year == year
               Aggregate.sum(entry.amount)
             else
               0
             end
           end
           row.new(*values)
         end
  end

  it 'generates waterfall with dynamic columns' do
    query = generate(2016, 2020)
    expected = <<~EOF
      with subquery0 as (
        select
          entries.person as person,
          entries.year as year,
          sum(entries.amount) as amount
        from entries
        where 2016 <= entries.year and entries.year <= 2020
        group by entries.person, entries.year
      )

      select
        subquery0.person as person,
        if(subquery0.year = 2016, sum(subquery0.amount), 0) as year_2016,
        if(subquery0.year = 2017, sum(subquery0.amount), 0) as year_2017,
        if(subquery0.year = 2018, sum(subquery0.amount), 0) as year_2018,
        if(subquery0.year = 2019, sum(subquery0.amount), 0) as year_2019,
        if(subquery0.year = 2020, sum(subquery0.amount), 0) as year_2020
      from subquery0
      group by subquery0.person
    EOF

    assert_content_equal(expected, generate_sql(query))
  end
end
