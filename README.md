lilit-sql
==========

lilit-sql is a Ruby library for composing production-grade SQLs
 
The APIs supports higher order primitives like parameterization and meta-programming.

It makes writing production-grade SQLs easier and more robust.

This is suitable for an application that builds analytics on top of SQL-supported data warehouses like Presto.

Why?
-----

In a production setting, the 2 needs often arise:
* There's a need to generate slightly different SQLs based on user's input. Conditional logic capability based on user's input is needed.
* There's a need to share a common logic. This is extremely difficult to do in SQL because it would require the common logic to be aware of the prior SQL's columns. It becomes infeasible when there are many SQLs using the same common part. Parameterization is needed.

lilit-sql solves the above needs by enabling conditional logic based on user's input and existing columns using Plain Old Ruby Code (PORC).


Examples
---------

```
Customer = Struct.new(:id, :name, :age)
Result = Struct.new(:level, :name)
  
query = Table.new(Customer, 'customers')
          .where {|c| c.name == 'test'}
          .map {|c| Result.new(c.level, c.name)}

puts generate_sql(query)
```

will generate:

```
select
  age as level, name
from customers
where name = 'test'
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
- [ ] Support expressions e.g.
  - [x] Support Plain Old Ruby Expressions
  - [ ] Formatting currency with if-else and multiplication.
- [ ] Support group by multiple keys
- [ ] Support cumulative SQL with inequality operators 
