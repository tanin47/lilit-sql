# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit_sql'
require_relative 'helpers'

class UnnestTest < Minitest::Spec
  it 'cross join and unnest' do
    entry = Struct.new(:student, :scores)
    unnest = Struct.new(:score)
    result = Struct.new(:student, :score)

    entries = Query.from(Table.new(entry, 'tests'))
    query = entries
            .cross_join_unnest { |row| unnest.new(row.scores) }
            .map { |row, unnested| result.new(row.student, unnested.score) }

    expected = <<~EOF
      select tests.student as student, t.score as score
      from tests
      cross join unnest (tests.scores) as t (score)
    EOF

    assert_content_equal(expected, generate_sql(query))
  end

  it 'with ordinality' do
    entry = Struct.new(:student, :scores)
    unnest = Struct.new(:score)
    result = Struct.new(:student, :score)

    entries = Query.from(Table.new(entry, 'tests'))
    query = entries
            .cross_join_unnest(ordinality: true) { |row| unnest.new(row.scores) }
            .map { |row, unnested| result.new(row.student, unnested.score) }

    expected = <<~EOF
      select tests.student as student, t.score as score
      from tests
      cross join unnest (tests.scores) with ordinality as t (score, ordinal)
    EOF

    assert_content_equal(expected, generate_sql(query))
  end
end
