defmodule DuckdbEx.DataIOTest do
  use ExUnit.Case

  alias DuckdbEx.Connection
  alias DuckdbEx.Relation

  setup do
    {:ok, conn} = Connection.connect(:memory)
    on_exit(fn -> Connection.close(conn) end)
    {:ok, conn: conn}
  end

  defp tmp_path(name) do
    unique = System.unique_integer([:positive])
    Path.join(System.tmp_dir!(), "duckdb_ex_#{name}_#{unique}")
  end

  test "read_csv reads CSV with header and delimiter", %{conn: conn} do
    csv_path = tmp_path("read_csv.csv")
    File.write!(csv_path, "a|b\n1|2\n3|4\n")

    relation = Connection.read_csv(conn, csv_path, header: true, sep: "|")
    assert {:ok, rows} = Relation.fetch_all(relation)
    assert rows == [{1, 2}, {3, 4}]
  end

  test "read_json reads newline-delimited JSON", %{conn: conn} do
    json_path = tmp_path("read_json.json")
    File.write!(json_path, ~s({"id":1,"name":"a"}\n{"id":2,"name":"b"}\n))

    relation = Connection.read_json(conn, json_path)
    assert {:ok, rows} = Relation.fetch_all(relation)
    assert rows == [{1, "a"}, {2, "b"}]
  end

  test "read_parquet reads parquet files", %{conn: conn} do
    parquet_path = tmp_path("read_parquet.parquet")

    Connection.execute(conn, "CREATE TABLE data (a INTEGER, b VARCHAR)")
    Connection.execute(conn, "INSERT INTO data VALUES (1, 'x'), (2, 'y')")
    Connection.execute(conn, "COPY data TO '#{parquet_path}' (FORMAT PARQUET)")

    relation = Connection.read_parquet(conn, parquet_path)
    assert {:ok, rows} = Relation.fetch_all(relation)
    assert Enum.sort_by(rows, &elem(&1, 0)) == [{1, "x"}, {2, "y"}]
  end

  test "to_csv writes relation results", %{conn: conn} do
    csv_path = tmp_path("to_csv.csv")

    relation =
      Connection.sql(conn, "SELECT * FROM (VALUES (1, 'x'), (2, 'y')) AS t(a, b) ORDER BY a")

    assert :ok = Relation.to_csv(relation, csv_path, header: true)

    csv_relation = Connection.read_csv(conn, csv_path, header: true)
    assert {:ok, rows} = Relation.fetch_all(csv_relation)
    assert rows == [{1, "x"}, {2, "y"}]
  end

  test "to_parquet writes relation results", %{conn: conn} do
    parquet_path = tmp_path("to_parquet.parquet")

    relation =
      Connection.sql(conn, "SELECT * FROM (VALUES (1, 'x'), (2, 'y')) AS t(a, b)")

    assert :ok = Relation.to_parquet(relation, parquet_path)

    parquet_relation = Connection.read_parquet(conn, parquet_path)
    assert {:ok, rows} = Relation.fetch_all(parquet_relation)
    assert Enum.sort_by(rows, &elem(&1, 0)) == [{1, "x"}, {2, "y"}]
  end

  test "to_parquet supports filename_pattern with partition_by", %{conn: conn} do
    out_dir = tmp_path("to_parquet_pattern")
    File.mkdir_p!(out_dir)

    relation =
      Connection.sql(
        conn,
        "SELECT * FROM (VALUES (1, 'a'), (2, 'b')) AS t(id, category)"
      )

    assert :ok =
             Relation.to_parquet(relation, out_dir,
               partition_by: ["category"],
               filename_pattern: "part_{i}"
             )

    parquet_files = Path.wildcard(Path.join(out_dir, "*/*.parquet"))
    assert parquet_files != []

    parquet_relation = Connection.read_parquet(conn, Path.join(out_dir, "*/*.parquet"))
    assert {:ok, rows} = Relation.fetch_all(parquet_relation)
    assert Enum.sort_by(rows, &elem(&1, 0)) == [{1, "a"}, {2, "b"}]
  end

  test "to_parquet supports file_size_bytes", %{conn: conn} do
    out_dir = tmp_path("to_parquet_size")
    File.mkdir_p!(out_dir)

    relation =
      Connection.sql(
        conn,
        "SELECT * FROM (VALUES (1, 'a'), (2, 'b')) AS t(id, category)"
      )

    assert :ok =
             Relation.to_parquet(relation, out_dir,
               filename_pattern: "chunk_{i}",
               file_size_bytes: 1
             )

    parquet_files = Path.wildcard(Path.join(out_dir, "*.parquet"))
    assert parquet_files != []

    parquet_relation = Connection.read_parquet(conn, Path.join(out_dir, "*.parquet"))
    assert {:ok, rows} = Relation.fetch_all(parquet_relation)
    assert Enum.sort_by(rows, &elem(&1, 0)) == [{1, "a"}, {2, "b"}]
  end
end
