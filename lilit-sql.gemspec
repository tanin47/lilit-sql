Gem::Specification.new do |s|
  s.name        = "lilit-sql"
  s.version     = "0.0.2"
  s.summary     = "lilit-sql is a Ruby DSL for composing production-grade analytical SQLs"
  s.description = "lilit-sql is a Ruby DSL for composing production-grade analytical SQLs

The DSL supports higher order primitives like parameterization and meta-programming, which makes writing production-grade analytical SQLs easier.

This is suitable for an application that builds analytics on top of SQL-supported data warehouses like Presto."
  s.authors     = ["Tanin Na Nakorn"]
  s.email       = "@tanin"
  s.files       = ["lib/lilit_sql.rb"]
  s.homepage    = "https://github.com/tanin47/lilit-sql"
  s.license       = "MIT"
end
