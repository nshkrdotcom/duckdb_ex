defmodule DuckdbEx.ConnectionTest do
  use ExUnit.Case

  # Reference: duckdb-python/tests/fast/test_connection.py

  defp tmp_path(name) do
    unique = System.unique_integer([:positive])
    Path.join(System.tmp_dir!(), "duckdb_ex_#{name}_#{unique}.duckdb")
  end

  describe "connect/2" do
    test "connects to memory database" do
      assert {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      assert is_pid(conn)
      DuckdbEx.Connection.close(conn)
    end

    test "connects with read_only option" do
      assert {:ok, conn} = DuckdbEx.Connection.connect(:memory, read_only: true)
      assert is_pid(conn)
      DuckdbEx.Connection.close(conn)
    end
  end

  describe "execute/3" do
    setup do
      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      on_exit(fn -> DuckdbEx.Connection.close(conn) end)
      {:ok, conn: conn}
    end

    test "executes SELECT 1", %{conn: conn} do
      assert {:ok, ^conn} = DuckdbEx.Connection.execute(conn, "SELECT 1")
      assert {:ok, rows} = DuckdbEx.Connection.fetch_all(conn)
      assert rows == [{1}]
    end

    test "executes CREATE TABLE", %{conn: conn} do
      assert {:ok, ^conn} =
               DuckdbEx.Connection.execute(conn, "CREATE TABLE test (id INTEGER, name VARCHAR)")
    end

    test "executes INSERT", %{conn: conn} do
      assert {:ok, ^conn} =
               DuckdbEx.Connection.execute(conn, "CREATE TABLE test (id INTEGER, name VARCHAR)")

      assert {:ok, ^conn} =
               DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (1, 'Alice')")
    end

    test "executes SELECT from table", %{conn: conn} do
      assert {:ok, ^conn} =
               DuckdbEx.Connection.execute(conn, "CREATE TABLE test (id INTEGER, name VARCHAR)")

      assert {:ok, ^conn} =
               DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (1, 'Alice')")

      assert {:ok, ^conn} = DuckdbEx.Connection.execute(conn, "SELECT * FROM test")
      assert {:ok, rows} = DuckdbEx.Connection.fetch_all(conn)
      assert rows == [{1, "Alice"}]
    end
  end

  describe "close/1" do
    test "closes connection successfully" do
      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      assert :ok = DuckdbEx.Connection.close(conn)
    end

    test "reopens file-backed connection after close" do
      db_path = tmp_path("reopen")
      on_exit(fn -> File.rm(db_path) end)

      {:ok, conn} = DuckdbEx.Connection.connect(db_path)
      {:ok, _} = DuckdbEx.Connection.execute(conn, "CREATE TABLE a (i INTEGER)")
      {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO a VALUES (42)")
      assert :ok = DuckdbEx.Connection.close(conn)

      {:ok, conn2} = DuckdbEx.Connection.connect(db_path)
      assert {:ok, rows} = DuckdbEx.Connection.fetch_all(conn2, "SELECT * FROM a")
      assert rows == [{42}]
      assert :ok = DuckdbEx.Connection.close(conn2)
    end
  end
end
