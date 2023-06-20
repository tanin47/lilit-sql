lilit-sql
==========

lilit-sql is a Ruby library that provides APIs for generating SQL statements. 

The APIs supports higher order primitives like generics, parameterization, and meta-programming.

It encourages code-reuse, enables unit-testing, and makes composing production-grade SQLs easier and more robust.

This is suitable for an application that builds analytics on top of data warehouses like Presto.

Examples
---------

```
Customer = Struct.new(:id, :name, :age)
Result = Struct.new(:age, :name)
  
query = Table.new(Customer, 'customers')
          .where {|c| c.name == 'test'}
          .map(Result) {|c| Result.new(c.age, c.name)}

puts query.generate_sql
```

will generate:

```
select
  age, name
from customers
where name = 'test'
```
