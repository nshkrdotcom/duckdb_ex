# Relations API Example (Lazy Query Building)
# Run with: mix run examples/04_relations_api.exs

alias DuckdbEx.Connection
alias DuckdbEx.Relation

IO.puts("=== Relations API (Lazy Queries) ===\n")

{:ok, conn} = Connection.connect(:memory)

# Setup test data
Connection.execute(conn, """
  CREATE TABLE products (
    id INTEGER,
    name VARCHAR,
    category VARCHAR,
    price DECIMAL(10,2),
    stock INTEGER
  )
""")

Connection.execute(conn, """
  INSERT INTO products VALUES
    (1, 'Laptop', 'Electronics', 999.99, 15),
    (2, 'Mouse', 'Electronics', 29.99, 150),
    (3, 'Desk', 'Furniture', 299.99, 8),
    (4, 'Chair', 'Furniture', 199.99, 12),
    (5, 'Monitor', 'Electronics', 349.99, 25),
    (6, 'Keyboard', 'Electronics', 79.99, 80),
    (7, 'Bookshelf', 'Furniture', 149.99, 5)
""")

IO.puts("✓ Products table created with 7 items\n")

# Example 1: Basic relation from table
IO.puts("1. Create relation from table:")
relation = Connection.table(conn, "products")
IO.puts("Created relation (not executed yet)")

# Example 2: Filter
IO.puts("\n2. Filter electronics:")

{:ok, electronics} =
  relation
  |> Relation.filter("category = 'Electronics'")
  |> Relation.fetch_all()

Enum.each(electronics, fn {_id, name, _category, price, _stock} ->
  IO.puts("  - #{name}: $#{price}")
end)

# Example 3: Multiple filters
IO.puts("\n3. Expensive electronics (price > $100):")

{:ok, expensive_electronics} =
  relation
  |> Relation.filter("category = 'Electronics'")
  |> Relation.filter("price > 100")
  |> Relation.fetch_all()

Enum.each(expensive_electronics, fn {_id, name, _category, price, _stock} ->
  IO.puts("  - #{name}: $#{price}")
end)

# Example 4: Projection (select specific columns)
IO.puts("\n4. Product names and prices only:")

{:ok, name_price} =
  relation
  |> Relation.project(["name", "price"])
  |> Relation.limit(3)
  |> Relation.fetch_all()

Enum.each(name_price, fn {name, price} ->
  IO.puts("  - #{name}: $#{price}")
end)

# Example 5: Ordering
IO.puts("\n5. Products by price (desc):")

{:ok, by_price} =
  relation
  |> Relation.order("price DESC")
  |> Relation.limit(3)
  |> Relation.fetch_all()

Enum.each(by_price, fn {_id, name, _category, price, _stock} ->
  IO.puts("  - #{name}: $#{price}")
end)

# Example 6: Aggregation
IO.puts("\n6. Aggregate by category:")

{:ok, by_category} =
  relation
  |> Relation.aggregate(
    ["COUNT(*) as count", "AVG(price)::DECIMAL(10,2) as avg_price", "SUM(stock) as total_stock"],
    group_by: ["category"]
  )
  |> Relation.fetch_all()

Enum.each(by_category, fn {category, count, avg_price, total_stock} ->
  IO.puts("  - #{category}: #{count} items, avg $#{avg_price}, #{total_stock} in stock")
end)

# Example 7: Complex chain
IO.puts("\n7. Low stock furniture items:")

{:ok, low_stock} =
  relation
  |> Relation.filter("category = 'Furniture'")
  |> Relation.filter("stock < 10")
  |> Relation.order("stock ASC")
  |> Relation.fetch_all()

Enum.each(low_stock, fn {_id, name, _category, _price, stock} ->
  IO.puts("  - #{name}: #{stock} units (RESTOCK NEEDED)")
end)

# Example 8: Using SQL relation
IO.puts("\n8. Custom SQL relation:")

{:ok, custom} =
  Connection.sql(conn, """
    SELECT
      category,
      name,
      price,
      CASE
        WHEN stock < 10 THEN 'LOW'
        WHEN stock < 50 THEN 'MEDIUM'
        ELSE 'HIGH'
      END as stock_level
    FROM products
  """)
  |> Relation.filter("stock_level = 'LOW'")
  |> Relation.fetch_all()

Enum.each(custom, fn {category, name, _price, stock_level} ->
  IO.puts("  - #{name} (#{category}): #{stock_level} stock")
end)

Connection.close(conn)
IO.puts("\n✓ Done")
