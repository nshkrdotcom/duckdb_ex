# Tables and Data Management Example
# Run with: mix run examples/02_tables_and_data.exs

alias DuckdbEx.Connection

IO.puts("=== Tables and Data Management ===\n")

{:ok, conn} = Connection.connect(:memory)

# Create a table
IO.puts("1. Creating table:")

{:ok, _} =
  Connection.execute(conn, """
    CREATE TABLE employees (
      id INTEGER PRIMARY KEY,
      name VARCHAR,
      department VARCHAR,
      salary INTEGER,
      hire_date DATE
    )
  """)

IO.puts("✓ Table 'employees' created")

# Insert data
IO.puts("\n2. Inserting data:")

{:ok, _} =
  Connection.execute(conn, """
    INSERT INTO employees VALUES
      (1, 'Alice Johnson', 'Engineering', 95000, '2020-01-15'),
      (2, 'Bob Smith', 'Sales', 75000, '2019-03-20'),
      (3, 'Carol Williams', 'Engineering', 105000, '2018-07-10'),
      (4, 'David Brown', 'Marketing', 70000, '2021-05-01'),
      (5, 'Eve Davis', 'Engineering', 88000, '2022-02-14')
  """)

IO.puts("✓ 5 employees inserted")

# Select all
IO.puts("\n3. SELECT all employees:")
{:ok, rows} = Connection.fetch_all(conn, "SELECT * FROM employees ORDER BY id")

Enum.each(rows, fn {id, name, department, salary, _hire_date} ->
  IO.puts("  #{id}. #{name} (#{department}) - $#{salary}")
end)

# Filter and aggregate
IO.puts("\n4. Average salary by department:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT
      department,
      COUNT(*) as employee_count,
      AVG(salary)::INTEGER as avg_salary,
      MIN(salary) as min_salary,
      MAX(salary) as max_salary
    FROM employees
    GROUP BY department
    ORDER BY avg_salary DESC
  """)

Enum.each(rows, fn {department, employee_count, avg_salary, _min_salary, _max_salary} ->
  IO.puts("  #{department}: #{employee_count} employees, avg $#{avg_salary}")
end)

# Update data
IO.puts("\n5. Giving Alice a raise:")

{:ok, _} =
  Connection.execute(conn, """
    UPDATE employees
    SET salary = salary + 10000
    WHERE name = 'Alice Johnson'
  """)

{:ok, [{name, salary}]} =
  Connection.fetch_all(conn, "SELECT name, salary FROM employees WHERE name = 'Alice Johnson'")

IO.puts("✓ #{name}'s new salary: $#{salary}")

# Delete data
IO.puts("\n6. Removing employees hired after 2021:")

{:ok, _} =
  Connection.execute(conn, """
    DELETE FROM employees WHERE hire_date > '2021-01-01'
  """)

{:ok, [{remaining}]} = Connection.fetch_all(conn, "SELECT COUNT(*) as remaining FROM employees")
IO.puts("✓ #{remaining} employees remaining")

# Drop table
IO.puts("\n7. Cleaning up:")
{:ok, _} = Connection.execute(conn, "DROP TABLE employees")
IO.puts("✓ Table dropped")

Connection.close(conn)
