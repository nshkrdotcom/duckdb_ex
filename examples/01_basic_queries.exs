# Basic Queries Example
# Run with: mix run examples/01_basic_queries.exs

alias DuckdbEx.Connection

IO.puts("=== Basic DuckDB Queries ===\n")

# Connect to in-memory database
{:ok, conn} = Connection.connect(:memory)
IO.puts("✓ Connected to in-memory database")

# Simple SELECT
IO.puts("\n1. Simple SELECT:")
{:ok, rows} = Connection.fetch_all(conn, "SELECT 1 as num, 'hello' as text")
IO.inspect(rows, label: "Result")

# Math operations
IO.puts("\n2. Math operations:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT
      42 + 8 as addition,
      100 - 25 as subtraction,
      7 * 6 as multiplication,
      100 / 4 as division,
      2 ^ 10 as power
  """)

IO.inspect(rows, label: "Math results")

# String operations
IO.puts("\n3. String operations:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT
      UPPER('hello world') as uppercase,
      LOWER('HELLO WORLD') as lowercase,
      CONCAT('Duck', 'DB') as concatenated,
      LENGTH('DuckDB') as length
  """)

IO.inspect(rows, label: "String operations")

# Date and time
IO.puts("\n4. Date and time:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT
      CURRENT_DATE as today,
      CURRENT_TIME as now,
      CURRENT_TIMESTAMP as timestamp,
      DATE '2024-01-15' + INTERVAL '7 days' as week_later
  """)

IO.inspect(rows, label: "Date/time")

# Aggregations
IO.puts("\n5. Aggregations:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT
      COUNT(*) as count,
      SUM(value) as sum,
      AVG(value) as average,
      MIN(value) as min,
      MAX(value) as max
    FROM (VALUES (1), (2), (3), (4), (5)) as t(value)
  """)

IO.inspect(rows, label: "Aggregations")

Connection.close(conn)
IO.puts("\n✓ Connection closed")
