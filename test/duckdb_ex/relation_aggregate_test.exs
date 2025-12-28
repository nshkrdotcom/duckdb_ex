defmodule DuckdbEx.RelationAggregateTest do
  use ExUnit.Case

  # Reference: duckdb-python/tests/fast/test_relation_api.py (aggregation tests)

  setup do
    {:ok, conn} = DuckdbEx.Connection.connect(:memory)
    on_exit(fn -> DuckdbEx.Connection.close(conn) end)
    {:ok, conn: conn}
  end

  describe "aggregate/2 - simple aggregations" do
    test "count all rows", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(10)")
        |> DuckdbEx.Relation.aggregate("count(*) as total")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{10}] = rows
    end

    test "sum aggregation", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(5)")
        |> DuckdbEx.Relation.aggregate("sum(range) as total")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # 0 + 1 + 2 + 3 + 4 = 10
      assert [{10}] = rows
    end

    test "avg aggregation", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(5)")
        |> DuckdbEx.Relation.aggregate("avg(range) as average")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # (0 + 1 + 2 + 3 + 4) / 5 = 2.0
      assert [{2.0}] = rows
    end

    test "min aggregation", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (value INT)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (5), (2), (8), (1), (9)")

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.aggregate("min(value) as minimum")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{1}] = rows
    end

    test "max aggregation", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (value INT)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (5), (2), (8), (1), (9)")

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.aggregate("max(value) as maximum")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{9}] = rows
    end

    test "count distinct", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (value INT)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (1), (2), (2), (3), (3), (3)")

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.aggregate("count(distinct value) as unique_count")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{3}] = rows
    end
  end

  describe "aggregate/2 - multiple aggregations" do
    test "multiple aggregates in one call", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(10)")
        |> DuckdbEx.Relation.aggregate([
          "count(*) as count",
          "sum(range) as total",
          "avg(range) as average",
          "min(range) as minimum",
          "max(range) as maximum"
        ])

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      assert [{10, 45, 4.5, 0, 9}] = rows
    end

    test "aggregates with expressions", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE sales (quantity INT, price DECIMAL)")

      DuckdbEx.Connection.execute(
        conn,
        "INSERT INTO sales VALUES (10, 5.00), (20, 3.00), (15, 4.00)"
      )

      relation =
        conn
        |> DuckdbEx.Connection.table("sales")
        |> DuckdbEx.Relation.aggregate([
          "sum(quantity) as total_quantity",
          "sum(quantity * price) as total_revenue"
        ])

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # 10*5 + 20*3 + 15*4 = 50 + 60 + 60 = 170
      assert [{45, revenue}] = rows
      assert_in_delta revenue, 170.0, 0.01
    end
  end

  describe "aggregate/3 - group by" do
    setup %{conn: conn} do
      DuckdbEx.Connection.execute(conn, """
        CREATE TABLE sales (
          product VARCHAR,
          category VARCHAR,
          amount INT,
          quantity INT
        )
      """)

      DuckdbEx.Connection.execute(conn, """
        INSERT INTO sales VALUES
          ('Laptop', 'Electronics', 1000, 2),
          ('Mouse', 'Electronics', 50, 10),
          ('Desk', 'Furniture', 300, 5),
          ('Chair', 'Furniture', 200, 8),
          ('Keyboard', 'Electronics', 100, 15)
      """)

      :ok
    end

    test "group by single column", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.table("sales")
        |> DuckdbEx.Relation.aggregate("sum(amount) as total", group_by: ["category"])

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 2

      electronics = Enum.find(rows, fn {category, _total} -> category == "Electronics" end)
      furniture = Enum.find(rows, fn {category, _total} -> category == "Furniture" end)

      # Laptop(1000) + Mouse(50) + Keyboard(100) = 1150
      assert elem(electronics, 1) == 1150
      # Desk(300) + Chair(200) = 500
      assert elem(furniture, 1) == 500
    end

    test "group by multiple columns", %{conn: conn} do
      DuckdbEx.Connection.execute(
        conn,
        "CREATE TABLE orders (region VARCHAR, year INT, sales INT)"
      )

      DuckdbEx.Connection.execute(conn, """
        INSERT INTO orders VALUES
          ('North', 2023, 100),
          ('North', 2023, 200),
          ('North', 2024, 150),
          ('South', 2023, 300),
          ('South', 2024, 250)
      """)

      relation =
        conn
        |> DuckdbEx.Connection.table("orders")
        |> DuckdbEx.Relation.aggregate("sum(sales) as total", group_by: ["region", "year"])

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 4

      north_2023 =
        Enum.find(rows, fn {region, year, _total} -> region == "North" and year == 2023 end)

      assert elem(north_2023, 2) == 300
    end

    test "group by with multiple aggregations", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.table("sales")
        |> DuckdbEx.Relation.aggregate(
          [
            "count(*) as count",
            "sum(amount) as total_amount",
            "avg(amount) as avg_amount",
            "sum(quantity) as total_quantity"
          ],
          group_by: ["category"]
        )

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 2

      electronics =
        Enum.find(rows, fn {category, _count, _total, _avg, _qty} -> category == "Electronics" end)

      assert elem(electronics, 1) == 3
      assert elem(electronics, 2) == 1150
      assert_in_delta elem(electronics, 3), 383.33, 0.1
      assert elem(electronics, 4) == 27
    end

    test "group by with filter", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.table("sales")
        |> DuckdbEx.Relation.filter("amount > 100")
        |> DuckdbEx.Relation.aggregate("sum(amount) as total", group_by: ["category"])

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      electronics = Enum.find(rows, fn {category, _total} -> category == "Electronics" end)
      furniture = Enum.find(rows, fn {category, _total} -> category == "Furniture" end)

      # Only Laptop(1000) for Electronics (Mouse and Keyboard filtered out)
      assert elem(electronics, 1) == 1000
      # Desk(300) + Chair(200) = 500
      assert elem(furniture, 1) == 500
    end

    test "group by with order", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.table("sales")
        |> DuckdbEx.Relation.aggregate("sum(amount) as total", group_by: ["category"])
        |> DuckdbEx.Relation.order("total DESC")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 2

      # Electronics should be first (1150 > 500)
      assert elem(hd(rows), 0) == "Electronics"
      assert elem(hd(rows), 1) == 1150
    end
  end

  describe "aggregate/3 - having clause" do
    setup %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE products (category VARCHAR, price INT)")

      DuckdbEx.Connection.execute(conn, """
        INSERT INTO products VALUES
          ('A', 100), ('A', 200), ('A', 50),
          ('B', 300), ('B', 400),
          ('C', 30)
      """)

      :ok
    end

    test "having with aggregation", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.table("products")
        |> DuckdbEx.Relation.aggregate("sum(price) as total", group_by: ["category"])
        |> DuckdbEx.Relation.filter("total > 200")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      # A: 350, B: 700, C: 30
      # Only A and B have total > 200
      assert length(rows) == 2
      assert Enum.all?(rows, fn {_category, total} -> total > 200 end)
    end
  end

  describe "convenience aggregate methods" do
    test "count/1 convenience method", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(10)")
        |> DuckdbEx.Relation.count()

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{10}] = rows
    end

    test "sum/2 convenience method", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(5)")
        |> DuckdbEx.Relation.sum("range")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{10}] = rows
    end

    test "avg/2 convenience method", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(5)")
        |> DuckdbEx.Relation.avg("range")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{2.0}] = rows
    end

    test "min/2 convenience method", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (value INT)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (5), (2), (8)")

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.min("value")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{2}] = rows
    end

    test "max/2 convenience method", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (value INT)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (5), (2), (8)")

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.max("value")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{8}] = rows
    end
  end

  describe "statistical aggregations" do
    test "standard deviation", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(1, 11)")
        |> DuckdbEx.Relation.aggregate("stddev_pop(range) as stddev")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # Standard deviation of 1-10 is approximately 2.87
      assert [{stddev}] = rows
      assert_in_delta stddev, 2.87, 0.1
    end

    test "variance", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(1, 11)")
        |> DuckdbEx.Relation.aggregate("var_pop(range) as variance")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # Variance of 1-10 is approximately 8.25
      assert [{variance}] = rows
      assert_in_delta variance, 8.25, 0.1
    end
  end

  describe "chaining with aggregations" do
    test "filter before and after aggregation", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE sales (category VARCHAR, amount INT)")

      DuckdbEx.Connection.execute(conn, """
        INSERT INTO sales VALUES
          ('A', 100), ('A', 200), ('A', 50),
          ('B', 300), ('B', 400), ('B', 10),
          ('C', 30), ('C', 20)
      """)

      relation =
        conn
        |> DuckdbEx.Connection.table("sales")
        # Filter before aggregation
        |> DuckdbEx.Relation.filter("amount > 50")
        # Aggregate
        |> DuckdbEx.Relation.aggregate("sum(amount) as total", group_by: ["category"])
        # Filter after aggregation (HAVING)
        |> DuckdbEx.Relation.filter("total > 300")
        # Order results
        |> DuckdbEx.Relation.order("total DESC")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      # A: 100+200 = 300 (filtered out by total > 300)
      # B: 300+400 = 700 (included)
      # C: none above 50
      assert length(rows) == 1
      assert [{"B", 700}] = rows
    end
  end
end
