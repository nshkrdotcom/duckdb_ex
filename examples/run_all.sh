#!/usr/bin/env bash
set -euo pipefail

if [ -z "${DUCKDB_PATH:-}" ]; then
  if [ -x "priv/duckdb/duckdb" ]; then
    export DUCKDB_PATH="$(pwd)/priv/duckdb/duckdb"
  elif command -v duckdb >/dev/null 2>&1; then
    export DUCKDB_PATH="$(command -v duckdb)"
  else
    echo "DUCKDB_PATH is not set, priv/duckdb/duckdb is missing, and duckdb is not in PATH." >&2
    echo "Run 'mix duckdb_ex.install' or export DUCKDB_PATH to the binary." >&2
    exit 1
  fi
fi

examples=(
  "examples/00_quickstart.exs"
  "examples/01_basic_queries.exs"
  "examples/02_tables_and_data.exs"
  "examples/03_transactions.exs"
  "examples/04_relations_api.exs"
  "examples/05_csv_parquet_json.exs"
  "examples/06_analytics_window_functions.exs"
  "examples/07_persistent_database.exs"
)

for example in "${examples[@]}"; do
  echo "Running ${example}..."
  mix run "${example}"
  echo ""
done
