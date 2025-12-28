defmodule DuckdbEx.TransactionTest do
  use ExUnit.Case

  # Reference: duckdb-python/tests/fast/test_transaction.py
  # Reference: TECHNICAL_DESIGN.md - Transaction API

  alias DuckdbEx.Connection

  setup do
    {:ok, conn} = Connection.connect(:memory)
    on_exit(fn -> Connection.close(conn) end)

    # Setup test table
    {:ok, _} = Connection.execute(conn, "CREATE TABLE accounts (id INTEGER, balance INTEGER)")

    {:ok, _} =
      Connection.execute(conn, "INSERT INTO accounts VALUES (1, 1000), (2, 500), (3, 750)")

    {:ok, conn: conn}
  end

  describe "begin/1" do
    test "begins a transaction", %{conn: conn} do
      assert {:ok, _result} = Connection.begin(conn)
    end

    test "can execute queries after begin", %{conn: conn} do
      assert {:ok, _} = Connection.begin(conn)

      assert {:ok, _} =
               Connection.execute(conn, "UPDATE accounts SET balance = 2000 WHERE id = 1")
    end
  end

  describe "commit/1" do
    test "commits a transaction", %{conn: conn} do
      assert {:ok, _} = Connection.begin(conn)

      assert {:ok, _} =
               Connection.execute(conn, "UPDATE accounts SET balance = 2000 WHERE id = 1")

      assert {:ok, _result} = Connection.commit(conn)
    end

    test "persists changes after commit", %{conn: conn} do
      {:ok, _} = Connection.begin(conn)
      {:ok, _} = Connection.execute(conn, "UPDATE accounts SET balance = 2000 WHERE id = 1")
      {:ok, _} = Connection.commit(conn)

      {:ok, rows} = Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE id = 1")
      assert [{2000}] = rows
    end
  end

  describe "rollback/1" do
    test "rolls back a transaction", %{conn: conn} do
      assert {:ok, _} = Connection.begin(conn)

      assert {:ok, _} =
               Connection.execute(conn, "UPDATE accounts SET balance = 2000 WHERE id = 1")

      assert {:ok, _result} = Connection.rollback(conn)
    end

    test "reverts changes after rollback", %{conn: conn} do
      {:ok, _} = Connection.begin(conn)
      {:ok, _} = Connection.execute(conn, "UPDATE accounts SET balance = 2000 WHERE id = 1")
      {:ok, _} = Connection.rollback(conn)

      {:ok, rows} = Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE id = 1")
      assert [{1000}] = rows
    end
  end

  describe "transaction/2 - managed transactions" do
    test "executes function within transaction", %{conn: conn} do
      result =
        Connection.transaction(conn, fn conn ->
          {:ok, _} =
            Connection.execute(conn, "UPDATE accounts SET balance = balance + 100 WHERE id = 1")

          :success
        end)

      assert {:ok, :success} = result
    end

    test "commits on successful execution", %{conn: conn} do
      {:ok, _} =
        Connection.transaction(conn, fn conn ->
          Connection.execute(conn, "UPDATE accounts SET balance = 2000 WHERE id = 1")
          :ok
        end)

      {:ok, rows} = Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE id = 1")
      assert [{2000}] = rows
    end

    test "rolls back on error", %{conn: conn} do
      result =
        Connection.transaction(conn, fn conn ->
          {:ok, _} = Connection.execute(conn, "UPDATE accounts SET balance = 2000 WHERE id = 1")
          # Simulate error
          {:error, :simulated_error}
        end)

      assert {:error, :simulated_error} = result

      # Verify rollback - balance should be unchanged
      {:ok, rows} = Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE id = 1")
      assert [{1000}] = rows
    end

    test "rolls back on exception", %{conn: conn} do
      result =
        Connection.transaction(conn, fn conn ->
          {:ok, _} = Connection.execute(conn, "UPDATE accounts SET balance = 2000 WHERE id = 1")
          raise "Intentional error"
        end)

      assert {:error, %RuntimeError{message: "Intentional error"}} = result

      # Verify rollback - balance should be unchanged
      {:ok, rows} = Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE id = 1")
      assert [{1000}] = rows
    end

    test "supports complex transaction logic", %{conn: conn} do
      {:ok, result} =
        Connection.transaction(conn, fn conn ->
          # Transfer money from account 1 to account 2
          {:ok, _} =
            Connection.execute(conn, "UPDATE accounts SET balance = balance - 100 WHERE id = 1")

          {:ok, _} =
            Connection.execute(conn, "UPDATE accounts SET balance = balance + 100 WHERE id = 2")

          # Return the new balances
          {:ok, rows} = Connection.fetch_all(conn, "SELECT id, balance FROM accounts ORDER BY id")
          rows
        end)

      assert [
               {1, 900},
               {2, 600},
               {3, 750}
             ] = result
    end

    test "handles nested operations", %{conn: conn} do
      {:ok, _} =
        Connection.transaction(conn, fn conn ->
          {:ok, _} =
            Connection.execute(conn, "UPDATE accounts SET balance = balance * 2 WHERE id = 1")

          {:ok, rows} = Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE id = 1")
          assert [{2000}] = rows
          :ok
        end)

      # Verify committed
      {:ok, rows} = Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE id = 1")
      assert [{2000}] = rows
    end

    test "transaction returns function result on success", %{conn: conn} do
      {:ok, result} =
        Connection.transaction(conn, fn conn ->
          {:ok, _} = Connection.execute(conn, "UPDATE accounts SET balance = 3000 WHERE id = 1")
          {:custom, :result, 42}
        end)

      assert {:custom, :result, 42} = result
    end

    test "rollback does not affect other connections", %{conn: conn} do
      # Start another connection
      {:ok, conn2} = Connection.connect(:memory)

      on_exit(fn -> Connection.close(conn2) end)

      # Create same table in conn2
      {:ok, _} = Connection.execute(conn2, "CREATE TABLE accounts (id INTEGER, balance INTEGER)")
      {:ok, _} = Connection.execute(conn2, "INSERT INTO accounts VALUES (1, 1000)")

      # Rollback transaction in conn1
      Connection.transaction(conn, fn conn ->
        {:ok, _} = Connection.execute(conn, "UPDATE accounts SET balance = 2000 WHERE id = 1")
        raise "Error"
      end)

      # conn1 should still have original value
      {:ok, rows1} = Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE id = 1")
      assert [{1000}] = rows1

      # conn2 should be unaffected
      {:ok, rows2} = Connection.fetch_all(conn2, "SELECT balance FROM accounts WHERE id = 1")
      assert [{1000}] = rows2
    end
  end

  describe "transaction error handling" do
    test "handles SQL errors in transaction", %{conn: conn} do
      result =
        Connection.transaction(conn, fn conn ->
          # This will fail - invalid SQL
          Connection.execute(conn, "UPDATE nonexistent_table SET x = 1")
        end)

      assert {:error, _} = result

      # Original data should be intact
      {:ok, rows} = Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE id = 1")
      assert [{1000}] = rows
    end

    test "handles constraint violations", %{conn: conn} do
      # Create table with constraint
      {:ok, _} =
        Connection.execute(
          conn,
          "CREATE TABLE users (id INTEGER PRIMARY KEY, name VARCHAR)"
        )

      {:ok, _} = Connection.execute(conn, "INSERT INTO users VALUES (1, 'Alice')")

      # Try to insert duplicate in transaction
      result =
        Connection.transaction(conn, fn conn ->
          Connection.execute(conn, "INSERT INTO users VALUES (1, 'Bob')")
        end)

      assert {:error, _} = result
    end
  end

  describe "transaction isolation" do
    test "changes not visible outside transaction until commit", %{conn: conn} do
      # Start transaction but don't commit
      {:ok, _} = Connection.begin(conn)
      {:ok, _} = Connection.execute(conn, "UPDATE accounts SET balance = 2000 WHERE id = 1")

      # In same connection, should see change
      {:ok, rows} = Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE id = 1")
      assert [{2000}] = rows

      # Rollback
      {:ok, _} = Connection.rollback(conn)

      # Should be back to original
      {:ok, rows} = Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE id = 1")
      assert [{1000}] = rows
    end
  end

  describe "checkpoint/1" do
    test "creates a checkpoint", %{conn: conn} do
      # Make some changes
      {:ok, _} = Connection.execute(conn, "UPDATE accounts SET balance = 2000 WHERE id = 1")

      # Checkpoint should succeed
      assert {:ok, _result} = Connection.checkpoint(conn)
    end
  end
end
