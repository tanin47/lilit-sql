# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit_sql'
require_relative 'helpers'

class WindowTest < Minitest::Spec
  it 'uses rank()' do
    skip 'not support it yet'
    entry = Struct.new(:student, :scores)
    unnest = Struct.new(:score)
    result = Struct.new(:student, :score)

    entries = Query.from(Table.new(entry, 'tests'))
    query = entries
            .cross_join_unnest { |row| unnest.new(row.scores) }
            .map { |row, unnested| result.new(row.student, unnested.score) }

    expected = <<~EOF
      select#{' '}
        orderkey, clerk, totalprice,
        rank() over (partition by clerk order by totalprice desc) as rnk
      from orders
      order by clerk, rnk
    EOF

    assert_content_equal(expected, generate_sql(query))
  end

  it 'sum over window' do
    skip 'not support it yet'
    entry = Struct.new(:student, :scores)
    unnest = Struct.new(:score)
    result = Struct.new(:student, :score)

    entries = Query.from(Table.new(entry, 'tests'))
    query = entries
            .cross_join_unnest { |row| unnest.new(row.scores) }
            .map { |row, unnested| result.new(row.student, unnested.score) }

    expected = <<~EOF
      select#{' '}
        clerk, orderdate, orderkey, totalprice,
        sum(totalprice) over (partition by clerk order by orderdate) as rolling_sum
      from orders
      order by clerk, orderdate, orderkey
    EOF

    assert_content_equal(expected, generate_sql(query))
  end
end
