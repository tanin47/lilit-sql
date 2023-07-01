lilit-sql
==========

[![Gem Version](https://badge.fury.io/rb/lilit-sql.svg)](https://rubygems.org/gems/lilit-sql)
[![Test](https://github.com/tanin47/lilit-sql/actions/workflows/ruby.yml/badge.svg)](https://github.com/tanin47/lilit-sql/actions)

lilit-sql is a Ruby DSL for composing maintainable production-grade analytical SQL statements.
 
The DSL supports higher order primitives like parameterization and meta-programming, which makes writing maintainable SQL statements easier.

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
  .aggregate do |keys, _main_row, prior_row| 
    Result.new(keys[0], Aggregate.sum(prior_row.amount_change))
  end

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

A dynamic column example:

```ruby
Entry = Struct.new(:person, :year, :amount)

def build(start_year, end_year)
  cols = [:person] + (start_year..end_year).map {|y| "year_#{y}".to_sym}.to_a
  row = Struct.new(*cols)
  Query.from(Table.new(Entry, 'entries'))
       .where {|entry| lit(start_year) <= entry.year and entry.year <= end_year}
       .group_by {|entry| [entry.person, entry.year]}
       .aggregate {|keys, entry| Entry.new(keys[0], keys[1], Aggregate.sum(entry.amount))}
       .group_by {|entry| entry.person}
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

puts generate_sql(build(2016, 2020))

# Output:
# with subquery0 as (
#   select
#     person,
#     year,
#     sum(amount) as amount
#   from entries
#   where 2016 <= year and year <= 2020
#   group by person, year
# )
# 
# select
#   person,
#   if(year = 2016, sum(amount), 0) as year_2016,
#   if(year = 2017, sum(amount), 0) as year_2017,
#   if(year = 2018, sum(amount), 0) as year_2018,
#   if(year = 2019, sum(amount), 0) as year_2019,
#   if(year = 2020, sum(amount), 0) as year_2020
# from subquery0
# group by person
```

Implementation detail
----------------------

Each function (e.g. map, where, group_by) call returns a Query, which can be later generated into a SQL.

Ruby's blocks are re-written using `sourcify` and `ruby2ruby` in order to provide a DSL that looks like Plain Old Ruby Code (PORC).

Two examples:
- `row.name == 'test'` is re-written into `row.name.new.eq(Literal.new(test))`, which later generates: `name = 'test'`.
- `if row.age <= 30; 'yes'; else; 'no'; end` is re-written into: `IfElse.new(row.age.lte(Literal.new(30)), Literal.new('yes'), Literal.new('no'))`, which later generates `if(age <= 30, 'yes', 'no')`.

FAQ
----

### What does Lilit mean?

Lilit in Thai (ลิลิต) is a Thai literary genre. 'Lilit' comes from 'Lalit' in Pali and Sansakrit languages. It means 'to play': to play rhythmic positions which have the same tone.

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
- [x] Add the waterfall example
- [x] Fix the integer and string literal
- [x] Refactor Expr. Everything is an expression basically.
- [x] Support unnest
- [x] Support order by and limit

Later:
- [ ] Support window function
- [ ] Integrate with Sorbet to support typed DSL. It's a bit too difficult.
