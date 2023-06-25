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
Result = Struct.new(:level, :name)
  
query = Table.new(Customer, 'customers')
          .where {|c| c.name == 'test'}
          .map {|c| Result.new(c.level, c.name)}

puts query.generate_sql
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
- [ ] Support multiple group bys.
