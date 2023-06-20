lilit-sql
==========

lilit-sql is a SQL-equivalent typed language that supports higher order primitives like generics, parameterization, and meta-programming.

Examples
---------

```
struct Customer(
  id: string,
  name: string,
  age: int
)

struct Result(
  name: string,
  age: Int
)

def main() {
  table[Customer]("customers")
    .filter { c => c.name == "test" }
    .map { c => Result(c.name, c.age) }  
}
```

will transpile to:

```
select
  name, age
from customers
where name = 'test'
```
