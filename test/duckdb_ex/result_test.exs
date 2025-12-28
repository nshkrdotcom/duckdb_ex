defmodule DuckdbEx.ResultTest do
  use ExUnit.Case

  alias DuckdbEx.Result

  describe "fetch_all/1" do
    test "fetches all rows from result" do
      result = %{rows: [{1}, {2}, {3}], row_count: 3, columns: ["a"]}
      assert Result.fetch_all(result) == [{1}, {2}, {3}]
    end

    test "returns empty list for empty result" do
      result = %{rows: [], row_count: 0, columns: []}
      assert Result.fetch_all(result) == []
    end
  end

  describe "fetch_one/1" do
    test "fetches first row from result" do
      result = %{rows: [{1}, {2}], row_count: 2, columns: ["a"]}
      assert Result.fetch_one(result) == {1}
    end

    test "returns nil for empty result" do
      result = %{rows: [], row_count: 0, columns: []}
      assert Result.fetch_one(result) == nil
    end
  end

  describe "fetch_many/2" do
    test "fetches N rows from result" do
      result = %{rows: [{1}, {2}, {3}, {4}], row_count: 4, columns: ["a"]}
      assert Result.fetch_many(result, 2) == [{1}, {2}]
    end

    test "fetches all available rows when N exceeds row count" do
      result = %{rows: [{1}, {2}], row_count: 2, columns: ["a"]}
      assert Result.fetch_many(result, 10) == [{1}, {2}]
    end
  end

  describe "row_count/1" do
    test "returns row count from result" do
      result = %{rows: [], row_count: 5, columns: []}
      assert Result.row_count(result) == 5
    end

    test "calculates row count from rows when not provided" do
      result = %{rows: [{1}, {2}, {3}], columns: ["a"]}
      assert Result.row_count(result) == 3
    end
  end

  describe "to_tuples/1" do
    test "converts rows to tuples" do
      result = %{rows: [{1, 2}, {3, 4}], row_count: 2, columns: ["a", "b"]}
      assert Result.to_tuples(result) == [{1, 2}, {3, 4}]
    end
  end

  describe "columns/1" do
    test "extracts column names from first row" do
      result = %{rows: [{1, 2}], row_count: 1, columns: ["a", "b"]}
      assert Result.columns(result) == ["a", "b"]
    end

    test "returns nil for empty result" do
      result = %{rows: [], row_count: 0, columns: []}
      assert Result.columns(result) == nil
    end
  end
end
