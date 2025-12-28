# Analytics and Window Functions Example
# Run with: mix run examples/06_analytics_window_functions.exs

alias DuckdbEx.Connection

IO.puts("=== Analytics and Window Functions ===\n")

{:ok, conn} = Connection.connect(:memory)

# Setup sales data
Connection.execute(conn, """
  CREATE TABLE sales (
    id INTEGER,
    date DATE,
    product VARCHAR,
    category VARCHAR,
    amount DECIMAL(10,2),
    region VARCHAR
  )
""")

Connection.execute(conn, """
  INSERT INTO sales VALUES
    (1, '2024-01-01', 'Laptop', 'Electronics', 1200.00, 'North'),
    (2, '2024-01-02', 'Mouse', 'Electronics', 25.00, 'North'),
    (3, '2024-01-02', 'Desk', 'Furniture', 400.00, 'South'),
    (4, '2024-01-03', 'Chair', 'Furniture', 250.00, 'South'),
    (5, '2024-01-03', 'Monitor', 'Electronics', 350.00, 'East'),
    (6, '2024-01-04', 'Keyboard', 'Electronics', 80.00, 'West'),
    (7, '2024-01-04', 'Bookshelf', 'Furniture', 180.00, 'North'),
    (8, '2024-01-05', 'Laptop', 'Electronics', 1200.00, 'East'),
    (9, '2024-01-05', 'Mouse', 'Electronics', 25.00, 'South'),
    (10, '2024-01-06', 'Desk', 'Furniture', 400.00, 'West')
""")

IO.puts("✓ Sales data loaded (10 transactions)\n")

# Window function: ROW_NUMBER
IO.puts("1. Ranking sales by amount (ROW_NUMBER):")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT
      ROW_NUMBER() OVER (ORDER BY amount DESC) as rank,
      product,
      amount,
      region
    FROM sales
    LIMIT 5
  """)

Enum.each(rows, fn {rank, product, amount, region} ->
  IO.puts("  ##{rank}: #{product} - $#{amount} (#{region})")
end)

# Window function: RANK by category
IO.puts("\n2. Ranking within each category (RANK):")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT
      category,
      product,
      amount,
      rank_in_category
    FROM (
      SELECT
        category,
        product,
        amount,
        RANK() OVER (PARTITION BY category ORDER BY amount DESC) as rank_in_category
      FROM sales
    ) ranked
    WHERE rank_in_category <= 2
    ORDER BY category, rank_in_category
  """)

Enum.each(rows, fn {category, product, amount, rank_in_category} ->
  IO.puts("  #{category} ##{rank_in_category}: #{product} - $#{amount}")
end)

# Running totals
IO.puts("\n3. Running total by date:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT
      date,
      product,
      amount,
      SUM(amount) OVER (ORDER BY date, id) as running_total
    FROM sales
    ORDER BY date, id
  """)

Enum.each(rows, fn {date, product, amount, running_total} ->
  IO.puts("  #{date}: #{product} ($#{amount}) - Running total: $#{running_total}")
end)

# Moving average
IO.puts("\n4. 3-day moving average:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT
      date,
      SUM(amount)::DECIMAL(10,2) as daily_total,
      AVG(SUM(amount)) OVER (
        ORDER BY date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
      )::DECIMAL(10,2) as moving_avg_3day
    FROM sales
    GROUP BY date
    ORDER BY date
  """)

Enum.each(rows, fn {date, daily_total, moving_avg_3day} ->
  IO.puts("  #{date}: Daily $#{daily_total}, 3-day avg $#{moving_avg_3day}")
end)

# LAG and LEAD
IO.puts("\n5. Comparing with previous/next day (LAG/LEAD):")

{:ok, rows} =
  Connection.fetch_all(conn, """
    WITH daily_sales AS (
      SELECT date, SUM(amount)::DECIMAL(10,2) as total
      FROM sales
      GROUP BY date
    )
    SELECT
      date,
      total,
      LAG(total) OVER (ORDER BY date) as prev_day,
      LEAD(total) OVER (ORDER BY date) as next_day,
      (total - LAG(total) OVER (ORDER BY date))::DECIMAL(10,2) as change
    FROM daily_sales
    ORDER BY date
  """)

Enum.each(rows, fn {date, total, _prev_day, _next_day, change} ->
  formatted_change = if change, do: "$#{change}", else: "N/A"
  IO.puts("  #{date}: $#{total} (change: #{formatted_change})")
end)

# Percentiles
IO.puts("\n6. Sales percentiles:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT
      product,
      amount,
      NTILE(4) OVER (ORDER BY amount) as quartile,
      PERCENT_RANK() OVER (ORDER BY amount) as percent_rank
    FROM sales
    ORDER BY amount DESC
    LIMIT 5
  """)

Enum.each(rows, fn {product, amount, quartile, percent_rank} ->
  percentile = Float.round(percent_rank * 100, 1)
  IO.puts("  #{product}: $#{amount} (Q#{quartile}, #{percentile}th percentile)")
end)

# Regional analysis
IO.puts("\n7. Regional performance:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT
      region,
      COUNT(*) as num_sales,
      SUM(amount)::DECIMAL(10,2) as total_sales,
      AVG(amount)::DECIMAL(10,2) as avg_sale,
      RANK() OVER (ORDER BY SUM(amount) DESC) as sales_rank
    FROM sales
    GROUP BY region
    ORDER BY total_sales DESC
  """)

Enum.each(rows, fn {region, num_sales, total_sales, avg_sale, sales_rank} ->
  IO.puts(
    "  ##{sales_rank} #{region}: #{num_sales} sales, $#{total_sales} total, $#{avg_sale} avg"
  )
end)

Connection.close(conn)
IO.puts("\n✓ Done")
