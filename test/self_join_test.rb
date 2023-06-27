# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit_sql'
require_relative 'helpers'

class SelfJoinTest < Minitest::Spec

  it 'performs cumulative sum' do
    mrr_change_struct = Struct.new(:year, :amount_change)
    result = Struct.new(:year, :mrr)

    mrr_changes = Query.from(Table.new(mrr_change_struct, 'mrr_changes'))
                       .map {|change| mrr_change_struct.new(change.year, change.amount_change * 100)}
    query = mrr_changes
      .left_join(mrr_changes) {|main, prior| prior.year <= main.year}
      .group_by {|main, _prior| main.year}
      .aggregate {|keys, _main_row, prior_row| result.new(keys[0], Aggregate.sum(prior_row.amount_change)) }

    expected = <<-EOF
with subquery0 as (
  select
    mrr_changes.year as year,
    mrr_changes.amount_change * 100 as amount_change
  from mrr_changes
)

select
  subquery0.year as year,
  sum(alias0.amount_change) as mrr
from subquery0
left join subquery0 alias0
on alias0.year <= subquery0.year
group by subquery0.year
    EOF

    assert_content_equal(expected, generate_sql(query))
  end
end
