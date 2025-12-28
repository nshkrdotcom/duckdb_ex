# Testing & Contributing

DuckdbEx follows strict TDD. Port tests from `duckdb-python` before adding new
features.

## Running Tests

```bash
mix test
mix credo --strict
mix dialyzer
```

## Formatting

```bash
mix format
```

## Requirements

- DuckDB CLI must be available (`DUCKDB_PATH` if not on PATH).
- Ensure examples run via `examples/run_all.sh`.

## Contribution Checklist

- Add or update ExUnit tests.
- Keep docs/examples in sync with behavior.
- Avoid breaking API parity with duckdb-python unless documented.
