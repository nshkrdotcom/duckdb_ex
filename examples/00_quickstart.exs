# Quickstart Example - Your first DuckDB query
# Run with: mix run examples/00_quickstart.exs

# Import the Connection module
alias DuckdbEx.Connection

# Connect to an in-memory database (fast, temporary)
{:ok, conn} = Connection.connect(:memory)
IO.puts("✓ Connected to DuckDB!")

# Execute a simple query and fetch rows
{:ok, rows} = Connection.fetch_all(conn, "SELECT 'Hello from DuckDB!' as message")

# Print the result
IO.inspect(rows, label: "Query result")

# Clean up
Connection.close(conn)
IO.puts("\n✓ Done! That was easy.")
IO.puts("\nTry more examples:")
IO.puts("  mix run examples/01_basic_queries.exs")
IO.puts("  mix run examples/02_tables_and_data.exs")
IO.puts("  mix run examples/03_transactions.exs")
