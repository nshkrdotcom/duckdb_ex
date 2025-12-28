# Transactions Example
# Run with: mix run examples/03_transactions.exs

alias DuckdbEx.Connection

IO.puts("=== Transaction Management ===\n")

{:ok, conn} = Connection.connect(:memory)

# Setup test data
Connection.execute(conn, """
  CREATE TABLE accounts (
    id INTEGER,
    name VARCHAR,
    balance INTEGER
  )
""")

Connection.execute(conn, """
  INSERT INTO accounts VALUES
    (1, 'Alice', 1000),
    (2, 'Bob', 500),
    (3, 'Carol', 750)
""")

IO.puts("Initial balances:")
{:ok, accounts} = Connection.fetch_all(conn, "SELECT * FROM accounts ORDER BY id")

Enum.each(accounts, fn {_id, name, balance} ->
  IO.puts("  #{name}: $#{balance}")
end)

# Example 1: Successful transaction
IO.puts("\n1. Successful transaction (transfer $200 from Alice to Bob):")

{:ok, _result} =
  Connection.transaction(conn, fn conn ->
    {:ok, _} =
      Connection.execute(conn, """
        UPDATE accounts SET balance = balance - 200 WHERE name = 'Alice'
      """)

    {:ok, _} =
      Connection.execute(conn, """
        UPDATE accounts SET balance = balance + 200 WHERE name = 'Bob'
      """)

    :success
  end)

{:ok, accounts} = Connection.fetch_all(conn, "SELECT * FROM accounts ORDER BY id")
IO.puts("After successful transfer:")

Enum.each(accounts, fn {_id, name, balance} ->
  IO.puts("  #{name}: $#{balance}")
end)

# Example 2: Transaction with automatic rollback on error
IO.puts("\n2. Transaction with error (attempting invalid transfer):")

result =
  Connection.transaction(conn, fn conn ->
    {:ok, _} =
      Connection.execute(conn, """
        UPDATE accounts SET balance = balance - 500 WHERE name = 'Bob'
      """)

    # Simulate a business logic error
    {:error, :insufficient_funds}
  end)

IO.puts("Transaction result: #{inspect(result)}")
{:ok, accounts} = Connection.fetch_all(conn, "SELECT * FROM accounts ORDER BY id")
IO.puts("Balances unchanged (rolled back):")

Enum.each(accounts, fn {_id, name, balance} ->
  IO.puts("  #{name}: $#{balance}")
end)

# Example 3: Transaction with exception
IO.puts("\n3. Transaction with exception:")

result =
  Connection.transaction(conn, fn conn ->
    {:ok, _} =
      Connection.execute(conn, """
        UPDATE accounts SET balance = balance - 100 WHERE name = 'Carol'
      """)

    raise "Something went wrong!"
  end)

IO.puts("Transaction result: #{inspect(result)}")
{:ok, accounts} = Connection.fetch_all(conn, "SELECT * FROM accounts ORDER BY id")
IO.puts("Balances unchanged (rolled back due to exception):")

Enum.each(accounts, fn {_id, name, balance} ->
  IO.puts("  #{name}: $#{balance}")
end)

# Example 4: Manual transaction control
IO.puts("\n4. Manual transaction control:")
{:ok, _} = Connection.begin(conn)

{:ok, _} =
  Connection.execute(conn, """
    UPDATE accounts SET balance = balance + 1000 WHERE name = 'Carol'
  """)

IO.puts("Inside transaction (not committed yet):")

{:ok, [{carol_balance}]} =
  Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE name = 'Carol'")

IO.puts("  Carol's balance: $#{carol_balance}")

{:ok, _} = Connection.rollback(conn)
IO.puts("After rollback:")

{:ok, [{carol_balance}]} =
  Connection.fetch_all(conn, "SELECT balance FROM accounts WHERE name = 'Carol'")

IO.puts("  Carol's balance: $#{carol_balance}")

Connection.close(conn)
IO.puts("\n✓ Done")
