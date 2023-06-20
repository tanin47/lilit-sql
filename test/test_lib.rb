# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit'

class CoolProgramTest < Minitest::Test

  Customer = Struct.new(:id, :name, :age)
  Result = Struct.new(:age, :name)

  def test_simple
    query = Table.new(Customer, 'customers')
         .where {|c| c.name == 'test'}
         .map(Result) {|c| Result.new(c.age, c.name)}

    assert_equal('Test SQL', query.generate_sql)
  end
end
