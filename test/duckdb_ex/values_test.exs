defmodule DuckdbEx.ValuesTest do
  use ExUnit.Case

  alias DuckdbEx.Connection
  alias DuckdbEx.Exceptions
  alias DuckdbEx.Relation

  setup do
    {:ok, conn} = Connection.connect(:memory)
    on_exit(fn -> Connection.close(conn) end)
    {:ok, conn: conn}
  end

  describe "values/2" do
    test "rejects empty input", %{conn: conn} do
      assert_raise Exceptions.InvalidInputException,
                   ~r/Could not create a ValueRelation without any inputs/,
                   fn ->
                     Connection.values(conn, [])
                   end
    end

    test "builds a single row from a list of values", %{conn: conn} do
      relation = Connection.values(conn, [1, 2, 3])
      {:ok, rows} = Relation.fetch_all(relation)
      assert rows == [{1, 2, 3}]
    end

    test "builds multiple rows from a list of tuples", %{conn: conn} do
      relation = Connection.values(conn, [{1, "one"}, {2, "two"}])
      {:ok, rows} = Relation.fetch_all(relation)
      assert rows == [{1, "one"}, {2, "two"}]
    end

    test "builds a single row from a tuple", %{conn: conn} do
      relation = Connection.values(conn, {1, 2, 3})
      {:ok, rows} = Relation.fetch_all(relation)
      assert rows == [{1, 2, 3}]
    end

    test "rejects mismatched tuple lengths", %{conn: conn} do
      assert_raise Exceptions.InvalidInputException,
                   ~r/Mismatch between length of tuples in input, expected 2 but found 1/,
                   fn ->
                     Connection.values(conn, [{1, 2}, {3}])
                   end
    end

    test "rejects empty tuples", %{conn: conn} do
      assert_raise Exceptions.InvalidInputException, ~r/Please provide a non-empty tuple/, fn ->
        Connection.values(conn, {})
      end
    end

    test "rejects mixed tuple and non-tuple inputs", %{conn: conn} do
      assert_raise Exceptions.InvalidInputException, ~r/Expected objects of type tuple/, fn ->
        Connection.values(conn, [{1, 2}, 3])
      end
    end
  end
end
