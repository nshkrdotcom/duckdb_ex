defmodule DuckdbEx.ParameterBindingTest do
  use ExUnit.Case

  alias DuckdbEx.Connection

  setup do
    {:ok, conn} = Connection.connect(:memory)
    on_exit(fn -> Connection.close(conn) end)
    {:ok, conn: conn}
  end

  describe "execute/3 parameter binding" do
    test "binds positional parameters", %{conn: conn} do
      assert {:ok, ^conn} =
               Connection.execute(
                 conn,
                 "SELECT CAST(? AS INTEGER), CAST(? AS INTEGER)",
                 ["42", "84"]
               )

      assert {:ok, rows} = Connection.fetch_all(conn)
      assert rows == [{42, 84}]
    end

    test "binds qmark parameters from list or tuple", %{conn: conn} do
      assert {:ok, ^conn} =
               Connection.execute(
                 conn,
                 "CREATE TABLE stocks (date text, trans text, symbol text, qty real, price real)"
               )

      assert {:ok, ^conn} =
               Connection.execute(
                 conn,
                 "INSERT INTO stocks VALUES ('2006-01-05','BUY','RHAT',100,35.14)"
               )

      assert {:ok, ^conn} =
               Connection.execute(conn, "SELECT COUNT(*) FROM stocks WHERE symbol=?", ["RHAT"])

      assert {:ok, rows} = Connection.fetch_all(conn)
      assert rows == [{1}]

      assert {:ok, ^conn} =
               Connection.execute(conn, "SELECT COUNT(*) FROM stocks WHERE symbol=?", {"RHAT"})

      assert {:ok, rows} = Connection.fetch_all(conn)
      assert rows == [{1}]
    end

    test "binds dollar parameters", %{conn: conn} do
      assert {:ok, ^conn} = Connection.execute(conn, "SELECT $1::INTEGER", [42])
      assert {:ok, rows} = Connection.fetch_all(conn)
      assert rows == [{42}]
    end
  end

  describe "executemany/3 parameter binding" do
    test "inserts multiple rows", %{conn: conn} do
      assert {:ok, ^conn} =
               Connection.execute(
                 conn,
                 "CREATE TABLE purchases (date text, trans text, symbol text, qty real, price real)"
               )

      purchases = [
        ["2006-03-28", "BUY", "IBM", 1000, 45.00],
        ["2006-04-05", "BUY", "MSFT", 1000, 72.00],
        ["2006-04-06", "SELL", "IBM", 500, 53.00]
      ]

      assert {:ok, ^conn} =
               Connection.executemany(conn, "INSERT INTO purchases VALUES (?,?,?,?,?)", purchases)

      assert {:ok, ^conn} = Connection.execute(conn, "SELECT count(*) FROM purchases")
      assert {:ok, rows} = Connection.fetch_all(conn)
      assert rows == [{3}]
    end
  end
end
