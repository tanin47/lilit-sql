# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/lilit_sql'
require_relative 'helpers'

class LookupTest < Minitest::Spec

  JournalEntry = Struct.new(:debit, :credit, :amount, :currency, :invoice, :charge)
  IncomeStatement = Struct.new(:account, :amount, :currency, :invoice)
  Invoice = Struct.new(:id, :number)
  Charge = Struct.new(:id, :description)

  def with_lookup(query)
    if query.has?(:invoice)
      invoices = Query.from(Table.new(Invoice, 'invoices'))
      query = query.left_join(invoices) do |*tables|
        left = tables.first
        invoice = tables.last

        left.invoice == invoice.id
      end
    end

    if query.has?(:charge)
      charges = Query.from(Table.new(Charge, 'charges'))
      query = query.left_join(charges) do |*tables|
        left = tables.first
        charge = tables.last

        left.charge == charge.id
      end
    end

    query
  end

  def inner_format_currency(amount, currency)
    expr do
      if currency in ['krw', 'jpy']
        amount
      else
        amount * 0.01
      end
    end
  end

  def format_currency(amount, currency)
    inner_format_currency(amount, currency)
  end

  it 'generates income statement' do
    entries = Query.from(Table.new(IncomeStatement, 'income_statement'))

    result = Struct.new(:account, :amount, :currency, :invoice, :invoice_number)

    query = with_lookup(entries)
      .map do |entry, invoice|
        result.new(
          entry.account,
          format_currency(entry.amount, entry.currency),
          entry.currency,
          entry.invoice,
          invoice.number,
       )
      end

    expected = <<-EOF
select
  income_statement.account as account,
  if(income_statement.currency in ('krw', 'jpy'), 
     income_statement.amount, 
     income_statement.amount * 0.01) as amount,
  income_statement.currency as currency,
  income_statement.invoice as invoice,
  invoices.number as invoice_number
from income_statement
left join invoices
on income_statement.invoice = invoices.id
EOF

    assert_content_equal(expected, generate_sql(query))
  end

  it 'generates journal entries' do
    entries = Query.from(Table.new(JournalEntry, 'journal_entries'))

    result = Struct.new(:debit, :credit, :amount, :currency, :invoice, :charge, :invoice_number, :charge_description)

    query = with_lookup(entries)
              .map do |entry, invoice, charge|
      formatted = format_currency(entry.amount, entry.currency)
      result.new(
        entry.debit,
        entry.credit,
        formatted,
        entry.currency,
        entry.invoice,
        entry.charge,
        invoice.number,
        charge.description
      )
    end

    expected = <<-EOF
select
  journal_entries.debit as debit,
  journal_entries.credit as credit,
  if(journal_entries.currency in ('krw', 'jpy'), 
     journal_entries.amount, 
     journal_entries.amount * 0.01) as amount,
  journal_entries.currency as currency,
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
