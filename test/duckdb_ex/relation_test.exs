defmodule DuckdbEx.RelationTest do
  use ExUnit.Case

  # Reference: duckdb-python/tests/fast/test_relation_api.py

  setup do
    {:ok, conn} = DuckdbEx.Connection.connect(:memory)
    on_exit(fn -> DuckdbEx.Connection.close(conn) end)
    {:ok, conn: conn}
  end

  describe "sql/2" do
    test "creates relation from SQL query", %{conn: conn} do
      # Create a relation without executing it
      relation = DuckdbEx.Connection.sql(conn, "SELECT 1 as x")

      assert %DuckdbEx.Relation{} = relation
      assert relation.conn == conn

      # Relation should be lazy - not executed yet
      # Execute when we fetch
      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{1}] = rows
    end

    test "creates relation from more complex query", %{conn: conn} do
      relation = DuckdbEx.Connection.sql(conn, "SELECT * FROM range(5)")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 5
      assert {0} = hd(rows)
    end
  end

  describe "table/2" do
    test "creates relation from table name", %{conn: conn} do
      # Setup test table
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (id INTEGER, name VARCHAR)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (1, 'Alice'), (2, 'Bob')")

      relation = DuckdbEx.Connection.table(conn, "test")

      assert %DuckdbEx.Relation{} = relation
      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 2
      assert {1, "Alice"} = hd(rows)
    end

    test "creates relation from view", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (id INTEGER)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test SELECT * FROM range(3)")

      DuckdbEx.Connection.execute(
        conn,
        "CREATE VIEW test_view AS SELECT * FROM test WHERE id > 0"
      )

      relation = DuckdbEx.Connection.table(conn, "test_view")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 2
    end
  end

  describe "project/2" do
    test "selects specific columns", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT 1 as x, 2 as y, 3 as z")
        |> DuckdbEx.Relation.project(["x", "y"])

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{1, 2}] = rows
      assert tuple_size(hd(rows)) == 2
    end

    test "projects single column", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (a INT, b INT, c INT)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (1, 2, 3)")

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.project(["a"])

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{1}] = rows
      assert tuple_size(hd(rows)) == 1
    end

    test "projects with expressions", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (name VARCHAR)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES ('alice'), ('bob')")

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.project(["upper(name) as upper_name"])

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert {"ALICE"} = hd(rows)
      assert {"BOB"} = Enum.at(rows, 1)
    end

    test "projects with multiple expressions", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT 5 as x")
        |> DuckdbEx.Relation.project(["x", "x * 2 as double", "x * 3 as triple"])

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{5, 10, 15}] = rows
    end
  end

  describe "filter/2" do
    test "filters rows with simple condition", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE nums (x INTEGER)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO nums SELECT * FROM range(10)")

      relation =
        conn
        |> DuckdbEx.Connection.table("nums")
        |> DuckdbEx.Relation.filter("x > 5")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # 6, 7, 8, 9
      assert length(rows) == 4
      assert Enum.all?(rows, fn {x} -> x > 5 end)
    end

    test "chains multiple filters", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE nums (x INTEGER)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO nums SELECT * FROM range(10)")

      relation =
        conn
        |> DuckdbEx.Connection.table("nums")
        |> DuckdbEx.Relation.filter("x > 2")
        |> DuckdbEx.Relation.filter("x < 8")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # 3, 4, 5, 6, 7
      assert length(rows) == 5
      assert Enum.all?(rows, fn {x} -> x > 2 and x < 8 end)
    end

    test "filters with complex condition", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (a INT, b INT)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (1, 10), (2, 20), (3, 30)")

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.filter("a * 10 = b")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 3
    end
  end

  describe "limit/2" do
    test "limits result rows", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(100)")
        |> DuckdbEx.Relation.limit(5)

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 5
    end

    test "limit larger than result set", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(3)")
        |> DuckdbEx.Relation.limit(10)

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 3
    end

    test "limit zero returns empty", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(10)")
        |> DuckdbEx.Relation.limit(0)

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert rows == []
    end

    test "supports offset", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(5)")
        |> DuckdbEx.Relation.limit(2, 1)

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert rows == [{1}, {2}]
    end
  end

  describe "order/2" do
    test "orders results ascending", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM (VALUES (3), (1), (2)) t(x)")
        |> DuckdbEx.Relation.order("x ASC")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{1}, {2}, {3}] = rows
    end

    test "orders results descending", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM (VALUES (3), (1), (2)) t(x)")
        |> DuckdbEx.Relation.order("x DESC")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{3}, {2}, {1}] = rows
    end

    test "orders by multiple columns", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (a INT, b INT)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (1, 2), (1, 1), (2, 1)")

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.order("a ASC, b DESC")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{1, 2}, {1, 1}, {2, 1}] = rows
    end
  end

  describe "sort/2" do
    test "sorts by a list of columns", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM (VALUES (3), (1), (2)) t(x)")
        |> DuckdbEx.Relation.sort(["x"])

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{1}, {2}, {3}] = rows
    end

    test "sorts by a string expression", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM (VALUES (3), (1), (2)) t(x)")
        |> DuckdbEx.Relation.sort("x DESC")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert [{3}, {2}, {1}] = rows
    end
  end

  describe "unique/2" do
    test "selects distinct values for specified columns", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (a INT, b INT)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (1, 1), (1, 2), (2, 1)")

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.unique("a")
        |> DuckdbEx.Relation.order("a")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert rows == [{1}, {2}]
    end
  end

  describe "chaining operations" do
    test "combines project, filter, order, and limit", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE users (id INT, name VARCHAR, age INT)")

      DuckdbEx.Connection.execute(conn, """
        INSERT INTO users VALUES
          (1, 'Alice', 30),
          (2, 'Bob', 25),
          (3, 'Charlie', 35),
          (4, 'Diana', 28),
          (5, 'Eve', 32)
      """)

      relation =
        conn
        |> DuckdbEx.Connection.table("users")
        |> DuckdbEx.Relation.filter("age > 26")
        |> DuckdbEx.Relation.project(["name", "age"])
        |> DuckdbEx.Relation.order("age DESC")
        |> DuckdbEx.Relation.limit(2)

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 2
      assert [{"Charlie", 35}, {"Eve", 32}] = rows
    end

    test "can reuse base relation", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE nums (x INT)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO nums SELECT * FROM range(10)")

      base = DuckdbEx.Connection.table(conn, "nums")

      # Two different branches from same base
      high = base |> DuckdbEx.Relation.filter("x > 7")
      low = base |> DuckdbEx.Relation.filter("x < 3")

      {:ok, high_rows} = DuckdbEx.Relation.fetch_all(high)
      {:ok, low_rows} = DuckdbEx.Relation.fetch_all(low)

      # 8, 9
      assert length(high_rows) == 2
      # 0, 1, 2
      assert length(low_rows) == 3
    end
  end

  describe "fetch operations" do
    test "fetch_all/1 returns all rows", %{conn: conn} do
      relation = DuckdbEx.Connection.sql(conn, "SELECT * FROM range(5)")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 5
      assert is_list(rows)
      assert Enum.all?(rows, &is_tuple/1)
    end

    test "fetch_one/1 returns first row", %{conn: conn} do
      relation = DuckdbEx.Connection.sql(conn, "SELECT * FROM range(5)")

      {:ok, row} = DuckdbEx.Relation.fetch_one(relation)
      assert {0} = row
    end

    test "fetch_one/1 returns nil for empty result", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(5)")
        |> DuckdbEx.Relation.filter("range > 100")

      {:ok, row} = DuckdbEx.Relation.fetch_one(relation)
      assert is_nil(row)
    end

    test "execute/1 returns result struct", %{conn: conn} do
      relation = DuckdbEx.Connection.sql(conn, "SELECT * FROM range(3)")

      {:ok, result} = DuckdbEx.Relation.execute(relation)
      assert is_map(result)
      assert Map.has_key?(result, :rows)
    end
  end
end
