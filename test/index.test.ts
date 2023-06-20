import compile from "../src";

it("basic code", () => {
  const code = `
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
`;

  const output = `
select
  name, age
from customers
where name = 'test'
`;

  expect(compile(code)).toBe(output);
});

it("group by", () => {
  const code = `
struct Customer(
  id: string,
  name: string,
  age: int
)

struct Result(
  age: Int,
  count: Int
)

def main() {
  table[Customer]("customers")
    .filter { c => c.name == "test" }
    .groupBy { c => c.age }
    .mapGroups { (key, values) => Result(key, count(values)) }
}
`;

  const output = `
select
  age, count(*)
from customers
where name = 'test'
group by age
`;

  expect(compile(code)).toBe(output);
});
