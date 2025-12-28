defmodule DuckdbEx.RelationMutationTest do
  use ExUnit.Case

  alias DuckdbEx.Connection
  alias DuckdbEx.Exceptions
  alias DuckdbEx.Relation

  setup do
    {:ok, conn} = Connection.connect(:memory)
    on_exit(fn -> Connection.close(conn) end)
    {:ok, conn: conn}
  end

  describe "create/2 and create_view/2" do
    test "creates a table from a relation", %{conn: conn} do
      relation = Connection.sql(conn, "SELECT 1 AS a, 'x' AS b")

      assert :ok = Relation.create(relation, "created_table")
      {:ok, rows} = Relation.fetch_all(Connection.table(conn, "created_table"))

      assert rows == [{1, "x"}]
    end

    test "creates a view from a relation", %{conn: conn} do
      relation = Connection.sql(conn, "SELECT 2 AS a")

      assert :ok = Relation.create_view(relation, "created_view")
      {:ok, rows} = Relation.fetch_all(Connection.table(conn, "created_view"))

      assert rows == [{2}]
    end
  end

  describe "insert_into/2 and insert/2" do
    test "inserts relation rows into an existing table", %{conn: conn} do
      Connection.execute(conn, "CREATE TABLE target (i INT, j VARCHAR)")

      relation = Connection.values(conn, [1, "one"])
      assert :ok = Relation.insert_into(relation, "target")

      {:ok, rows} = Relation.fetch_all(Connection.table(conn, "target"))
      assert rows == [{1, "one"}]
    end

    test "inserts values into a table relation", %{conn: conn} do
      Connection.execute(conn, "CREATE TABLE target (i INT, j VARCHAR)")

      relation = Connection.table(conn, "target")
      assert :ok = Relation.insert(relation, [2, "two"])
      assert :ok = Relation.insert(relation, {3, "three"})

      {:ok, rows} = Relation.fetch_all(relation)
      assert rows == [{2, "two"}, {3, "three"}]
    end

    test "rejects insert on non-table relations", %{conn: conn} do
      relation = Connection.sql(conn, "SELECT 1 AS a")

      assert_raise Exceptions.InvalidInputException,
                   ~r/can only be used on a table relation/,
                   fn ->
                     Relation.insert(relation, [1])
                   end
    end
  end

  describe "update/3" do
    test "updates rows with a condition", %{conn: conn} do
      Connection.execute(conn, "CREATE TABLE target (a VARCHAR, b INT)")
      Connection.execute(conn, "INSERT INTO target VALUES ('hello', 21), ('hello', 42)")

      relation = Connection.table(conn, "target")
      assert :ok = Relation.update(relation, %{"a" => "test"}, "b = 42")

      {:ok, rows} = Relation.fetch_all(relation)
      assert rows == [{"hello", 21}, {"test", 42}]
    end

    test "rejects empty update sets", %{conn: conn} do
      Connection.execute(conn, "CREATE TABLE target (a VARCHAR, b INT)")

      relation = Connection.table(conn, "target")

      assert_raise Exceptions.InvalidInputException,
                   ~r/Please provide at least one set expression/,
                   fn ->
                     Relation.update(relation, %{})
                   end
    end

    test "rejects non-string update keys", %{conn: conn} do
      Connection.execute(conn, "CREATE TABLE target (a VARCHAR, b INT)")

      relation = Connection.table(conn, "target")

      assert_raise Exceptions.InvalidInputException,
                   ~r/Please provide the column name as the key of the dictionary/,
                   fn ->
                     Relation.update(relation, %{1 => 21})
                   end
    end
  end
end
