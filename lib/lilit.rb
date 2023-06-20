# frozen_string_literal: true

module Query
  def where
    self
  end

  def group_by
    self
  end

  def map(struct, &blk)
    self
  end

  def generate_sql
    "Test SQL"
  end
end

class Table
  include Query

  def initialize(struct, table_name)
  end
end
