# Relation API Guide

Relations are lazy query builders. They build SQL but do not execute until you
call a fetch method.

## Create Relations

```elixir
{:ok, conn} = DuckdbEx.Connection.connect(:memory)
rel = DuckdbEx.Connection.table(conn, "orders")
rel = DuckdbEx.Connection.sql(conn, "SELECT * FROM orders")
rel = DuckdbEx.Connection.values(conn, [1, "a"])
rel = DuckdbEx.Connection.values(conn, [{1, "a"}, {2, "b"}])
```

## Build Queries

```elixir
rel =
  rel
  |> DuckdbEx.Relation.filter("amount > 100")
  |> DuckdbEx.Relation.project(["customer", "amount"])
  |> DuckdbEx.Relation.order("amount DESC")
  |> DuckdbEx.Relation.limit(10)
```

Use an offset when you need to skip rows:

```elixir
rel |> DuckdbEx.Relation.limit(10, 5)
```

## Execute

```elixir
{:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
```

Rows are tuples in column order.

## Aggregations

```elixir
rel =
  rel
  |> DuckdbEx.Relation.aggregate(
    ["sum(amount) as total", "count(*) as cnt"],
    group_by: ["region"]
  )
```

## Joins & Set Operations

```elixir
joined = DuckdbEx.Relation.join(rel1, rel2, "rel1.id = rel2.id", type: :left)
unioned = DuckdbEx.Relation.union(rel1, rel2)
```

## Create/Insert/Update

```elixir
rel = DuckdbEx.Connection.sql(conn, "SELECT 1 AS a, 'x' AS b")
DuckdbEx.Relation.create(rel, "table_from_rel")
DuckdbEx.Relation.create_view(rel, "view_from_rel")

table = DuckdbEx.Connection.table(conn, "table_from_rel")
DuckdbEx.Relation.insert(table, [2, "y"])
DuckdbEx.Relation.update(table, %{"b" => "z"}, "a = 2")
```
