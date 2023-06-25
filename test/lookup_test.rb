# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit'
require_relative 'helpers'

class LookupTest < Minitest::Test

  JournalEntry = Struct.new(:debit, :credit, :amount, :invoice, :charge)
  IncomeStatement = Struct.new(:account, :amount, :invoice)
  Invoice = Struct.new(:id, :number)
  Charge = Struct.new(:id, :description)

  def with_lookup(query)
    query = if query.has?(:invoice)
              invoices = Query.new(Table.new(Invoice, 'invoices'))
              query.left_join(invoices) do |*tables|
                left = tables.first
                invoice = tables.last
                left.col(:invoice).eq(invoice.col(:id))
              end
            else
              query
            end

    query = if query.has?(:charge)
              charges = Query.new(Table.new(Charge, 'charges'))
              query.left_join(charges) do |*tables|
                left = tables.first
                charge = tables.last
                left.col(:charge).eq(charge.col(:id))
              end
            else
              query
            end

    query
  end

  def test_income_statement
    entries = Query.new(Table.new(IncomeStatement, 'income_statement'))

    result = Struct.new(:account, :amount, :invoice, :invoice_number)

    query = with_lookup(entries)
      .map do |entry, invoice|
        result.new(
          entry.col(:account),
          entry.col(:amount),
          entry.col(:invoice),
          invoice.col(:number),
       )
      end

    expected = <<-EOF
select
  income_statement.account as account,
  income_statement.amount as amount,
  income_statement.invoice as invoice,
  invoices.number as invoice_number
from income_statement
left join invoices
on income_statement.invoice = invoices.id
EOF

    assert_content_equal(expected, generate_sql(query))
  end

  def test_journal_entry
    entries = Query.new(Table.new(JournalEntry, 'journal_entries'))

    result = Struct.new(:debit, :credit, :amount, :invoice, :charge, :invoice_number, :charge_description)

    query = with_lookup(entries)
              .map do |entry, invoice, charge|
      result.new(
        entry.col(:debit),
        entry.col(:credit),
        entry.col(:amount),
        entry.col(:invoice),
        entry.col(:charge),
        invoice.col(:number),
        charge.col(:description)
      )
    end

    expected = <<-EOF
select
  journal_entries.debit as debit,
  journal_entries.credit as credit,
  journal_entries.amount as amount,
  journal_entries.invoice as invoice,
  journal_entries.charge as charge,
  invoices.number as invoice_number,
  charges.description as charge_description
from journal_entries
left join invoices
on journal_entries.invoice = invoices.id
left join charges
on journal_entries.charge = charges.id
    EOF

    assert_content_equal(expected, generate_sql(query))
  end
end
