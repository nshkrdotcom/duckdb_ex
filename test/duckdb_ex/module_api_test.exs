defmodule DuckdbEx.ModuleApiTest do
  use ExUnit.Case

  alias DuckdbEx.Connection
  alias DuckdbEx.Exceptions
  alias DuckdbEx.Relation

  setup do
    DuckdbEx.close()
    :ok
  end

  describe "default connection" do
    test "module-level execute uses default connection" do
      assert {:ok, _conn} = DuckdbEx.execute("SELECT 1 AS a")
      assert {:ok, rows} = DuckdbEx.fetchall()
      assert rows == [{1}]
    end

    test "connect :default returns default connection" do
      assert {:ok, _conn} =
               DuckdbEx.execute("CREATE OR REPLACE TABLE connect_default_connect (i INTEGER)")

      assert {:ok, _conn} = DuckdbEx.execute("INSERT INTO connect_default_connect VALUES (1)")
      assert {:ok, default_conn} = DuckdbEx.connect(":default:")

      relation = Connection.sql(default_conn, "SELECT i FROM connect_default_connect")
      assert {:ok, rows} = Relation.fetch_all(relation)
      assert rows == [{1}]

      assert {:ok, _conn} = DuckdbEx.execute("DROP TABLE connect_default_connect")

      assert {:error, %Exceptions.CatalogException{}} = Relation.fetch_all(relation)
    end

    test "connect :default with options errors" do
      assert {:error, %Exceptions.InvalidInputException{}} =
               DuckdbEx.connect(":default:", read_only: true)
    end
  end

  describe "module-level helpers" do
    test "executemany inserts rows" do
      assert {:ok, _} = DuckdbEx.execute("CREATE TABLE mod_tbl (i INTEGER, j VARCHAR)")

      assert {:ok, _} =
               DuckdbEx.executemany(
                 "INSERT INTO mod_tbl VALUES (?, ?)",
                 [
                   [5, "test"],
                   [2, "duck"],
                   [42, "quack"]
                 ]
               )

      relation = DuckdbEx.table("mod_tbl")
      assert {:ok, rows} = Relation.fetch_all(relation)
      assert Enum.sort_by(rows, &elem(&1, 0)) == [{2, "duck"}, {5, "test"}, {42, "quack"}]

      assert {:ok, _} = DuckdbEx.execute("DROP TABLE mod_tbl")
    end

    test "cursor duplicates default connection" do
      unique = System.unique_integer([:positive])
      db_path = Path.join(System.tmp_dir!(), "duckdb_ex_default_cursor_test_#{unique}.duckdb")

      on_exit(fn ->
        DuckdbEx.close()
        File.rm(db_path)
      end)

      assert {:ok, conn} = DuckdbEx.connect(db_path)
      assert :ok = DuckdbEx.set_default_connection(conn)

      assert {:ok, _} = DuckdbEx.execute("CREATE TABLE cursor_tbl (i INTEGER)")
      assert {:ok, cursor} = DuckdbEx.cursor()
      relation = Connection.table(cursor, "cursor_tbl")
      assert {:ok, rows} = Relation.fetch_all(relation)
      assert rows == []
      Connection.close(cursor)

      assert {:ok, _} = DuckdbEx.execute("DROP TABLE cursor_tbl")
    end

    test "duplicate is alias for cursor" do
      unique = System.unique_integer([:positive])
      db_path = Path.join(System.tmp_dir!(), "duckdb_ex_default_dup_test_#{unique}.duckdb")

      on_exit(fn ->
        DuckdbEx.close()
        File.rm(db_path)
      end)

      assert {:ok, conn} = DuckdbEx.connect(db_path)
      assert :ok = DuckdbEx.set_default_connection(conn)

      assert {:ok, dup_conn} = DuckdbEx.duplicate()
      assert match?(%DuckdbEx.Cursor{}, dup_conn)
      Connection.close(dup_conn)
    end

    test "description and rowcount reflect last result" do
      assert {:ok, _} = DuckdbEx.execute("SELECT 42::INTEGER AS answer")
      assert {:ok, description} = DuckdbEx.description()
      assert description == [{"answer", "INTEGER", nil, nil, nil, nil, nil}]
      assert DuckdbEx.rowcount() == -1
    end
  end

  describe "extract_statements/1" do
    test "parses statement metadata" do
      assert {:error, %Exceptions.ParserException{}} =
               DuckdbEx.extract_statements("seledct 42; select 21")

      assert {:ok, statements} = DuckdbEx.extract_statements("select $1; select 21")
      assert length(statements) == 2

      [first, second] = statements
      assert first.query == "select $1"
      assert first.type == DuckdbEx.StatementType.select()
      assert first.named_parameters == MapSet.new(["1"])
      assert first.expected_result_type == [DuckdbEx.ExpectedResultType.query_result()]

      assert second.query == " select 21"
      assert second.type == DuckdbEx.StatementType.select()
      assert second.named_parameters == MapSet.new()
    end

    test "execute accepts statement and params" do
      assert {:ok, statements} = DuckdbEx.extract_statements("select $1; select 21")
      [first, second] = statements

      assert {:error, %Exceptions.InvalidInputException{}} = DuckdbEx.execute(first)
      assert {:ok, _} = DuckdbEx.execute(first, %{"1" => 42})
      assert {:ok, rows} = DuckdbEx.fetchall()
      assert rows == [{42}]

      assert {:ok, _} = DuckdbEx.execute(second)
      assert {:ok, rows} = DuckdbEx.fetchall()
      assert rows == [{21}]
    end

    test "executemany errors on empty params" do
      assert {:ok, _} = DuckdbEx.execute("CREATE TABLE exec_many_tbl (a INTEGER)")

      assert {:ok, statements} =
               DuckdbEx.extract_statements("insert into exec_many_tbl select $1")

      [statement] = statements

      assert {:error, %Exceptions.InvalidInputException{}} = DuckdbEx.executemany(statement)
      assert {:ok, _} = DuckdbEx.executemany(statement, [[21], [22], [23]])

      relation = DuckdbEx.table("exec_many_tbl")
      assert {:ok, rows} = Relation.fetch_all(relation)
      assert rows == [{21}, {22}, {23}]

      assert {:ok, _} = DuckdbEx.execute("DROP TABLE exec_many_tbl")
    end
  end
end
