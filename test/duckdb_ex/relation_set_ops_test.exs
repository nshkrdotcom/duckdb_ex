defmodule DuckdbEx.RelationSetOpsTest do
  use ExUnit.Case

  # Reference: duckdb-python/tests/fast/test_relation_api.py (set operations & distinct tests)

  setup do
    {:ok, conn} = DuckdbEx.Connection.connect(:memory)
    on_exit(fn -> DuckdbEx.Connection.close(conn) end)
    {:ok, conn: conn}
  end

  describe "distinct/1" do
    test "removes duplicate rows", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (x INT)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (1), (2), (2), (3), (3), (3)")

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.distinct()

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 3
      assert Enum.sort_by(rows, &elem(&1, 0)) == [{1}, {2}, {3}]
    end

    test "distinct on multiple columns", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (x INT, y VARCHAR)")

      DuckdbEx.Connection.execute(
        conn,
        "INSERT INTO test VALUES (1, 'a'), (1, 'a'), (1, 'b'), (2, 'a')"
      )

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.distinct()

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 3
    end

    test "distinct with no duplicates returns same count", %{conn: conn} do
      relation =
        conn
        |> DuckdbEx.Connection.sql("SELECT * FROM range(10)")
        |> DuckdbEx.Relation.distinct()

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 10
    end

    test "distinct can be chained with other operations", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (x INT)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (1), (2), (2), (3), (3), (3)")

      relation =
        conn
        |> DuckdbEx.Connection.table("test")
        |> DuckdbEx.Relation.filter("x > 1")
        |> DuckdbEx.Relation.distinct()
        |> DuckdbEx.Relation.order("x ASC")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert rows == [{2}, {3}]
    end
  end

  describe "union/2" do
    test "unions two relations", %{conn: conn} do
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT 1 as x UNION SELECT 2")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT 2 as x UNION SELECT 3")

      relation = DuckdbEx.Relation.union(rel1, rel2)
      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      # UNION removes duplicates, so we get 1, 2, 3
      assert length(rows) == 3
      values = Enum.map(rows, &elem(&1, 0)) |> Enum.sort()
      assert values == [1, 2, 3]
    end

    test "union with identical relations", %{conn: conn} do
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT 1 as x UNION SELECT 2")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT 1 as x UNION SELECT 2")

      relation = DuckdbEx.Relation.union(rel1, rel2)
      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      # UNION removes duplicates
      assert length(rows) == 2
    end

    test "union with different column names uses first relation's names", %{conn: conn} do
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT 1 as x")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT 2 as y")

      relation = DuckdbEx.Relation.union(rel1, rel2)

      {:ok, result} = DuckdbEx.Relation.execute(relation)
      rows = DuckdbEx.Result.fetch_all(result)

      # DuckDB uses the first relation's column names
      assert length(rows) == 2
      assert DuckdbEx.Result.columns(result) == ["x"]
    end

    test "union can be chained", %{conn: conn} do
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT 1 as x")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT 2 as x")
      rel3 = DuckdbEx.Connection.sql(conn, "SELECT 3 as x")

      relation =
        rel1
        |> DuckdbEx.Relation.union(rel2)
        |> DuckdbEx.Relation.union(rel3)

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 3
    end
  end

  describe "intersect/2" do
    test "finds common rows between relations", %{conn: conn} do
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (1), (2), (3)) t(x)")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (2), (3), (4)) t(x)")

      relation = DuckdbEx.Relation.intersect(rel1, rel2)
      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      assert length(rows) == 2
      values = Enum.map(rows, &elem(&1, 0)) |> Enum.sort()
      assert values == [2, 3]
    end

    test "intersect with no common rows returns empty", %{conn: conn} do
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT 1 as x")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT 2 as x")

      relation = DuckdbEx.Relation.intersect(rel1, rel2)
      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      assert rows == []
    end

    test "intersect with identical relations returns same rows", %{conn: conn} do
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (1), (2)) t(x)")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (1), (2)) t(x)")

      relation = DuckdbEx.Relation.intersect(rel1, rel2)
      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      assert length(rows) == 2
    end
  end

  describe "except_/2" do
    test "returns rows in first relation but not in second", %{conn: conn} do
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (1), (2), (3)) t(x)")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (2), (3), (4)) t(x)")

      relation = DuckdbEx.Relation.except_(rel1, rel2)
      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      assert length(rows) == 1
      assert rows == [{1}]
    end

    test "except with identical relations returns empty", %{conn: conn} do
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT 1 as x")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT 1 as x")

      relation = DuckdbEx.Relation.except_(rel1, rel2)
      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      assert rows == []
    end

    test "except with no common rows returns first relation", %{conn: conn} do
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (1), (2)) t(x)")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (3), (4)) t(x)")

      relation = DuckdbEx.Relation.except_(rel1, rel2)
      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      assert length(rows) == 2
      values = Enum.map(rows, &elem(&1, 0)) |> Enum.sort()
      assert values == [1, 2]
    end
  end

  describe "set operations combined" do
    test "complex set operation chain", %{conn: conn} do
      # (A UNION B) INTERSECT C
      rel_a = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (1), (2)) t(x)")
      rel_b = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (2), (3)) t(x)")
      rel_c = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (2), (3), (4)) t(x)")

      relation =
        rel_a
        |> DuckdbEx.Relation.union(rel_b)
        |> DuckdbEx.Relation.intersect(rel_c)

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)

      values = Enum.map(rows, &elem(&1, 0)) |> Enum.sort()
      assert values == [2, 3]
    end
  end
end
