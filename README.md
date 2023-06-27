lilit-sql
==========

lilit-sql is a Ruby DSL for composing production-grade analytical SQLs
 
The DSL supports higher order primitives like parameterization and meta-programming, which makes writing production-grade analytical SQLs easier.

This is suitable for an application that builds analytics on top of SQL-supported data warehouses like Presto.

Installation
-------------

Add the below line to your Gemfile:

```
gem 'lilit-sql'
```

Try a simple example:

```ruby
require 'lilit_sql'

Customer = Struct.new(:id, :name, :age)
Result = Struct.new(:level, :name)
  
query = Table.new(Customer, 'customers')
          .where {|c| c.name == 'test' and c.age == 30}
          .map {|c| Result.new(c.level, c.name)}

puts generate_sql(query)
```

Please note that lilit-sql doesn't work in IRB. You will need to put the code in a file.

Why?
-----

In a production setting, the 2 needs often arise:
* There's a need to generate different SQLs/columns based on user's input. A conditional logic capability based on user's input is needed.
* There's a need to share a common logic. This is extremely difficult to do in SQL because it would require the common logic to be aware of the prior SQL's columns. It becomes infeasible when there are many SQLs using the same common part. A parameterization capability is needed.

lilit-sql solves the above needs by enabling conditional logic based on user's input and existing columns using Plain Old Ruby Code (PORC).


Examples
---------

A simple example:

```ruby
Customer = Struct.new(:id, :name, :age)
Result = Struct.new(:level, :name)
  
query = Table.new(Customer, 'customers')
          .where {|c| c.name == 'test' and c.age == 30}
          .map {|c| Result.new(c.level, c.name)}

puts generate_sql(query)

# Output:
# select
#   age as level, name
# from customers
# where name = 'test' and age = 30
```

A complex example where common conditional logic is shared:

```ruby
JournalEntry = Struct.new(:debit, :credit, :amount, :currency, :invoice_id, :charge_id)
JournalEntryReport = Struct.new(:debit, :credit, :amount, :currency, :invoice_id, :charge_id, :invoice_number, :charge_description)

IncomeStatement = Struct.new(:account, :amount, :currency, :invoice_id)
IncomeStatementReport = Struct.new(:account, :amount, :currency, :invoice_id, :invoice_number)

Invoice = Struct.new(:id, :number)
Charge = Struct.new(:id, :description)
  
def with_lookup(query)
  if query.has?(:invoice_id)
    invoices = Query.from(Table.new(Invoice, 'invoices'))
    query = query.left_join(invoices) do |*tables|
      left = tables.first
      invoice = tables.last

      left.invoice_id == invoice.id
    end
  end

  if query.has?(:charge_id)
    charges = Query.from(Table.new(Charge, 'charges'))
    query = query.left_join(charges) do |*tables|
      left = tables.first
      charge = tables.last

      left.charge_id == charge.id
    end
  end
end

def format_currency(amount, currency)
  expr do
    if currency in ['krw', 'jpy']
      amount
    else
      amount * 0.01
    end
  end
end

journal_entries = Query.from(Table.new(JournalEntry, 'journal_entries'))

journal_entry_query = with_lookup(journal_entries).map do |entry, invoice, charge|
  JournalEntryReport.new(
    entry.debit,
    entry.credit,
    format_currency(entry.amount, entry.currency),
    entry.currency,
    entry.invoice_id,
    entry.charge_id,
    invoice.number,
    charge.description
  )
end

puts generate_sql(journal_entry_query)

# Output:
# select
#   debit,
#   credit,
#   if(currency in ('krw', 'jpy'), amount, amount * 0.01) as amount,
#   currency,
#   invoice_id,
#   charge_id,
#   invoices.number as invoice_number,
#   charges.description as charge_description
# from journal_entries 
# left join invoices on invoice_id = invoices.id
# left join charges on charge_id = charges.id

income_statement_entries = Query.from(Table.new(IncomeStatement, 'income_statement'))

income_statement_query = with_lookup(income_statement_entries).map do |entry, invoice|
  IncomeStatementReport.new(
    entry.account,
    format_currency(entry.amount, entry.currency),
    entry.currency,
    entry.invoice_id,
    invoice.number,
  )
end

puts generate_sql(income_statement_query)

# Output:
# select
#   account,
#   if(currency in ('krw', 'jpy'), amount, amount * 0.01) as amount,
#   currency,
#   invoice_id,
#   invoices.number as invoice_number
# from income_statement
# left join invoices on invoice_id = invoices.id
```

A cumulative sum example:

```ruby
MrrChange = Struct.new(:year, :amount_change)
Result = Struct.new(:year, :mrr)

mrr_changes = Query.from(Table.new(MrrChange, 'mrr_changes'))

query = mrr_changes
  .left_join(mrr_changes) {|main, prior| prior.year <= main.year}
  .group_by {|main, _prior| main.year}
  .aggregate {|keys, _main_row, prior_row| Result.new(keys[0], Aggregate.sum(prior_row.amount_change)) }

puts generate_sql(query)

# Output: 
# with q as (
#   select
#     year,
#     amount_change
#   from mrr_changes
# )
# 
# select
#   q.year as year,
#   sum(cumulative.amount_change) as mrr
# from q
# left join q cumulative on cumulative.year <= q.year
# group by q.year
```

Tasks
------
- [x] Support simple filter
- [x] Support simple group by
- [x] Support multiple maps that should generate sub-query
- [x] Support multiple group bys
- [x] Support joins
- [x] Support left joins
- [x] Implement the lookup framework based on the columns
  - 2 reports: debits-credits and income statement -- different starting point and ending point.
- [x] Support expressions e.g.
  - [x] Support Plain Old Ruby Expressions
  - [x] Formatting currency with if-else
  - [x] Support multiplication.
- [x] Support group by multiple keys
- [x] Support cumulative SQL with inequality operators 
- [ ] Refactor Expr
- [ ] Support unnest
- [ ] Support window function
- [ ] Make it support Presto
