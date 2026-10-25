#!/usr/bin/env bash
# Create the lobster milestones, labels and issues on GitHub.
# One issue per requirement in PROJECT.md. Safe to re-run: it skips an issue
# whose title already exists.
set -euo pipefail

REPO="${REPO:-msohail22/lobster}"

echo "== milestones =="
while IFS='|' read -r title desc; do
  gh api "repos/$REPO/milestones" -f title="$title" -f description="$desc" >/dev/null 2>&1 \
    && echo "created  $title" || echo "exists   $title"
done <<'MS'
M1 Skeleton and storage|Weeks 1-2: build system, shell, types, column files
M2 Compression|Weeks 3-4: codecs None, LZ4, Delta, Dict with checksums
M3 Parser and basic queries|Weeks 5-6: tokenizer, parser, row engine, DuckDB comparison
M4 Vectorized engine|Weeks 7-9: vectorized operators, min/max skipping, EXPLAIN
M5 Threads and benchmarks|Weeks 10-12: multithreading, full benchmark suite, sanitizers
MS

echo "== labels =="
while IFS='|' read -r name color desc; do
  gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" >/dev/null 2>&1 \
    && echo "created  $name" || echo "exists   $name"
done <<'LB'
ui|1d76db|Shell and output
storage|0e8a16|Column files, blocks, durability
compression|fbca04|Codecs and checksums
parser|5319e7|Tokenizer, AST, SQL surface
engine|b60205|Execution operators
testing|c2e0c6|Unit tests, sanitizers, fuzzing
benchmark|d93f0b|Measurement and profiling
infra|bfd4f2|Build, CI, formatting
docs|e4e669|README and DESIGN
LB

EXISTING="$(gh issue list --repo "$REPO" --state all --limit 500 --json title --jq '.[].title')"

mk() { # mk <milestone> <labels> <title> <body>
  if grep -Fxq "$3" <<<"$EXISTING"; then echo "exists   $3"; return; fi
  gh issue create --repo "$REPO" --milestone "$1" --label "$2" --title "$3" --body "$4" >/dev/null
  echo "created  $3"
}

# ---------------------------------------------------------------- M1
mk "M1 Skeleton and storage" infra "ER-1: CMake C++20 build, clean under -Wall -Wextra on GCC and Clang" \
'C++20 project built with CMake.

**Done when:** the project builds with both GCC and Clang with no warnings at `-Wall -Wextra`.'
mk "M1 Skeleton and storage" infra "ER-2: vendor LZ4 and GoogleTest only" \
'Dependencies are LZ4 and GoogleTest only. DuckDB is an external tool used for testing, not linked. Everything else is our own code.

**Done when:** a fresh clone configures and builds without pulling any other library.'
mk "M1 Skeleton and storage" infra "ER-3: one-command debug, release and sanitizer builds" \
'Debug, release and sanitizer builds are each a single command (CMake presets, or documented commands).

**Done when:** `CMakePresets.json` (or README) gives one command per build type and all three work.'
mk "M1 Skeleton and storage" infra "ER-4: GitHub Actions CI on every push" \
'CI builds with GCC and Clang, runs unit tests, runs the sanitizer build, and runs the DuckDB comparison.

**Done when:** every push gets a green check. (The DuckDB and sanitizer steps can be added as those features land.)'
mk "M1 Skeleton and storage" infra "ER-5: .clang-format and compile_commands.json export" \
'Add `.clang-format` and enable `CMAKE_EXPORT_COMPILE_COMMANDS`.

**Done when:** formatting and clangd behave the same in any editor on any machine.'
mk "M1 Skeleton and storage" docs "ER-6: pick one error-handling approach and record it in DESIGN.md" \
'Choose exceptions or `std::expected` and use it consistently.

**Done when:** `DESIGN.md` names the choice, the alternative, and why; the code follows it.'
mk "M1 Skeleton and storage" ui "FR-UI-1: --data-dir <path> holds all tables" \
'All tables live under the directory given by `--data-dir`.

**Done when:** two shells with different directories see different tables.'
mk "M1 Skeleton and storage" ui "FR-UI-2: interactive shell, one statement per line ending in ;" \
'Read one statement per line, ended by `;`. Exit on `exit`, `quit` or Ctrl-D.

**Done when:** statements run one after another and Ctrl-D exits cleanly.'
mk "M1 Skeleton and storage" ui "FR-UI-3: non-interactive mode with -q" \
'Run a single statement: `lobster --data-dir ./data -q "SELECT ..."`.

**Done when:** the benchmark script can call lobster without the shell.'
mk "M1 Skeleton and storage" ui "FR-UI-6: errors print a clear message and keep the shell running" \
'**Done when:** a bad query never crashes or exits the shell.'
mk "M1 Skeleton and storage" storage "FR-DT-1: support Int32, Int64, Float64 and String columns" \
'**Done when:** each type round-trips from CSV to disk and back without change.'
mk "M1 Skeleton and storage" storage "FR-DT-2: strings are UTF-8 bytes of any length, compared byte-wise" \
'**Done when:** a string with commas, quotes and non-ASCII text round-trips.'
mk "M1 Skeleton and storage" storage "FR-DT-3: no NULL support; empty numeric CSV field is an error" \
'An empty CSV field is an error for numeric columns and an empty string for `String`.

**Done when:** import of an empty numeric field fails and names the line number.'
mk "M1 Skeleton and storage" storage "FR-DT-4: tables are append-only; a second COPY appends" \
'**Done when:** two imports of 1M rows give a table of 2M rows.'
mk "M1 Skeleton and storage" storage "FR-DT-5: validate table and column names" \
'Letters, digits and `_`, starting with a letter. Names are case-sensitive.

**Done when:** invalid names give an error at CREATE TABLE.'
mk "M1 Skeleton and storage" storage "FR-DT-6: DROP TABLE deletes the table and its files" \
'**Done when:** the table directory is gone and the name can be reused.'
mk "M1 Skeleton and storage" storage "FR-ST-1: one directory per table, one data file per column" \
'**Done when:** `ls data/trips/` shows one file per column plus metadata.'
mk "M1 Skeleton and storage" storage "FR-ST-2: metadata file with schema, codecs, row count and block count" \
'**Done when:** lobster restarts and lists the same tables with the same schemas.'
mk "M1 Skeleton and storage" storage "FR-ST-3: fixed-size row blocks, default 8192, configurable at CREATE TABLE" \
'The last block may be smaller.

**Done when:** a table of 20,000 rows has 3 blocks.'

# ---------------------------------------------------------------- M2
mk "M2 Compression" compression "FR-CO-1: codec None (raw values)" \
'**Done when:** it works as the baseline for all codec comparisons.'
mk "M2 Compression" compression "FR-CO-2: codec LZ4 using the LZ4 library, default for all columns" \
'**Done when:** round-trip tests pass on random and real data.'
mk "M2 Compression" compression "FR-CO-3: codec Delta for integers, chainable as CODEC(Delta, LZ4)" \
'Our own implementation.

**Done when:** sorted integers compress better with Delta+LZ4 than with LZ4 alone.'
mk "M2 Compression" compression "FR-CO-4: codec Dict for String columns" \
'Store each distinct value once and replace values with small integer IDs. Our own implementation.

**Done when:** a column with 5 distinct values compresses more than 10x.'
mk "M2 Compression" compression "FR-CO-5: reject invalid codec choices" \
'For example `Delta` on a `String`.

**Done when:** CREATE TABLE gives a clear error.'
mk "M2 Compression" compression "FR-CO-6: DESCRIBE shows type, codec, sizes and ratio per column" \
'**Done when:** the output matches the sizes of the files on disk.'
mk "M2 Compression" compression "FR-CO-7: per-block checksum detects corrupt data" \
'**Done when:** flipping one byte in a column file gives a checksum error on query, not a crash.'
mk "M2 Compression" testing "FR-TE-2: codec round-trip tests on edge cases" \
'Empty block, one value, all same values, min and max of each type, random data.

**Done when:** all pass.'
mk "M2 Compression" benchmark "FR-BM-5: codec comparison table (ratio and decompression MB/s)" \
'Measure compression ratio and decompression speed per codec on real columns.

**Done when:** a codec table is in the README.'

# ---------------------------------------------------------------- M3
mk "M3 Parser and basic queries" parser "FR-QL-1: SELECT a column list or *" \
'**Done when:** `SELECT fare, payment FROM trips LIMIT 5` works.'
mk "M3 Parser and basic queries" parser "FR-QL-2: aggregates COUNT, SUM, AVG, MIN, MAX with AS aliases" \
'`COUNT(*)`, `COUNT(col)`, `SUM`, `AVG`, `MIN`, `MAX`.

**Done when:** each aggregate matches DuckDB on the test data.'
mk "M3 Parser and basic queries" parser "FR-QL-3: WHERE with comparisons, AND, OR, NOT and parentheses" \
'Operators `=` `!=` `<` `<=` `>` `>=` comparing a column to a literal.

**Done when:** `WHERE (distance > 5 OR fare > 50) AND payment = '"'"'card'"'"'` works.'
mk "M3 Parser and basic queries" parser "FR-QL-4: GROUP BY one or more columns" \
'Every non-aggregate column in SELECT must be in GROUP BY.

**Done when:** invalid mixes give a clear error.'
mk "M3 Parser and basic queries" parser "FR-QL-5: ORDER BY column, alias or position, ASC/DESC, multiple keys" \
'**Done when:** `ORDER BY 2 DESC, payment` works.'
mk "M3 Parser and basic queries" parser "FR-QL-6: LIMIT n" \
'**Done when:** only n rows print.'
mk "M3 Parser and basic queries" parser "FR-QL-7: case-insensitive keywords, single-quoted string literals" \
'**Done when:** `select count(*) from trips` works.'
mk "M3 Parser and basic queries" parser "FR-QL-8: errors name the problem and the position" \
'Unknown table, unknown column, type mismatch, syntax error.

**Done when:** `SELECT fare FROM trips WHERE fare > '"'"'abc'"'"'` gives a type error, not a crash.'
mk "M3 Parser and basic queries" parser "Add DESCRIBE and SHOW TABLES statements" \
'The statement set is CREATE TABLE, DROP TABLE, COPY ... FROM, DESCRIBE, SHOW TABLES, SELECT.

**Done when:** `SHOW TABLES` lists the tables and `DESCRIBE t` prints the schema.'
mk "M3 Parser and basic queries" engine "FR-EX-7: row-at-a-time baseline engine behind --engine=row" \
'Runs the same queries without vectorization. This is the "before" number for every "after" number in the benchmarks.

**Done when:** benchmarks can compare both modes on the same query.'
mk "M3 Parser and basic queries" ui "FR-UI-4: print results as an aligned text table with column names" \
'**Done when:** output is readable for up to about 20 columns.'
mk "M3 Parser and basic queries" ui "FR-UI-5: print elapsed time, rows read and bytes read after each query" \
'**Done when:** every SELECT prints something like `10 rows. Elapsed: 0.214 s. Read 10.0M rows, 81 MB`.'
mk "M3 Parser and basic queries" testing "FR-TE-1: GoogleTest unit tests for codecs, tokenizer, parser, hash table, operators" \
'**Done when:** `ctest` runs all of them in under a minute.'
mk "M3 Parser and basic queries" testing "FR-TE-3: query test suite of at least 50 queries in a text file" \
'Covers every FR-QL requirement.

**Done when:** the file exists and runs in CI.'
mk "M3 Parser and basic queries" testing "FR-TE-4: DuckDB comparison script" \
'Load the same CSV into DuckDB, run each test query in both, compare results (floats within a small tolerance).

**Done when:** every query matches.'

# ---------------------------------------------------------------- M4
mk "M4 Vectorized engine" engine "FR-EX-1: operators process one block of column values at a time" \
'Vectorized, not row at a time.

**Done when:** the hot loops in `perf` are tight loops over arrays.'
mk "M4 Vectorized engine" engine "FR-EX-2: scan reads only the columns the query needs" \
'Columns used in SELECT, WHERE, GROUP BY and ORDER BY.

**Done when:** bytes read for `SELECT SUM(fare)` equals the fare column size only.'
mk "M4 Vectorized engine" engine "FR-EX-4: own hash table for GROUP BY" \
'Open addressing recommended, the design is ours to choose.

**Done when:** it handles 10M distinct keys without errors and the design is documented in `DESIGN.md`.'
mk "M4 Vectorized engine" engine "FR-EX-6: ORDER BY ... LIMIT n keeps only the top n rows with a heap" \
'**Done when:** `LIMIT 10` on 10M groups uses far less memory than a full sort.'
mk "M4 Vectorized engine" storage "FR-ST-4: per-block min/max index file for every column" \
'**Done when:** a test reads the index and checks min/max against the raw data.'
mk "M4 Vectorized engine" storage "FR-ST-5: read one block of one column without reading the others" \
'**Done when:** bytes read for a one-block query is close to one block'"'"'s size.'
mk "M4 Vectorized engine" engine "FR-EX-3: skip blocks the min/max index proves cannot match WHERE" \
'**Done when:** on data sorted by `pickup_day`, a one-day filter reads under 5% of blocks.'
mk "M4 Vectorized engine" storage "FR-ST-6: block-by-block scans never load a whole column into memory" \
'**Done when:** a query on a table 2x larger than RAM finishes without running out of memory.'
mk "M4 Vectorized engine" storage "FR-ST-7: crash-safe COPY" \
'An interrupted import leaves the table as it was before the import. Learn `fsync` and write-then-rename here.

**Done when:** killing lobster during COPY and restarting gives the old row count.'
mk "M4 Vectorized engine" parser "FR-QL-9: EXPLAIN SELECT prints the plan and the blocks the index will skip" \
'**Done when:** the output shows the pipeline for any valid query.'

# ---------------------------------------------------------------- M5
mk "M5 Threads and benchmarks" engine "FR-EX-5: multithreaded scan, filter and aggregate with --threads N" \
'Each thread works on its own blocks and builds a partial result; partials merge at the end. Default thread count is the CPU core count.

**Done when:** results are the same for 1 and N threads.'
mk "M5 Threads and benchmarks" testing "FR-TE-5: full query suite passes under ThreadSanitizer" \
'**Done when:** no TSan reports.'
mk "M5 Threads and benchmarks" testing "FR-TE-6: full test suite passes under AddressSanitizer and UBSan" \
'**Done when:** no ASan or UBSan reports.'
mk "M5 Threads and benchmarks" testing "FR-TE-7: fuzz the parser with random and malformed input" \
'libFuzzer or a simple random generator.

**Done when:** one hour of fuzzing gives no crash.'
mk "M5 Threads and benchmarks" benchmark "FR-BM-1: fixed datasets - ClickBench hits sample plus a seeded synthetic set" \
'For example 10M rows of hits, plus one generated dataset with a fixed seed.

**Done when:** a script downloads or generates both the same way every time.'
mk "M5 Threads and benchmarks" benchmark "FR-BM-2: fixed query set of 10-15 benchmark queries" \
'Full scans, selective filters, low- and high-cardinality GROUP BY, and `ORDER BY ... LIMIT`.

**Done when:** the queries live in the repo as files.'
mk "M5 Threads and benchmarks" benchmark "FR-BM-3: ./bench/run.sh runs everything, 1 cold and 5 warm runs, median reported" \
'Cold means the page cache is dropped first.

**Done when:** two runs on the same machine differ by under 10%.'
mk "M5 Threads and benchmarks" benchmark "FR-BM-4: compare lobster vectorized vs --engine=row vs DuckDB" \
'Same data, same machine.

**Done when:** a results table is in the README.'
mk "M5 Threads and benchmarks" benchmark "FR-BM-6: thread scaling at 1, 2, 4 and N threads" \
'**Done when:** a scaling chart is in the README, with an explanation of where it stops scaling.'
mk "M5 Threads and benchmarks" benchmark "FR-BM-7: record the environment with every result" \
'CPU, RAM, disk, OS, compiler, flags and commit hash.

**Done when:** each results file has this header.'
mk "M5 Threads and benchmarks" benchmark "FR-BM-8: two perf flame graphs with before and after write-ups" \
'What was slow, what changed, the before and after numbers.

**Done when:** two write-ups are in `bench/README.md`, ready to reuse as blog posts.'
mk "M5 Threads and benchmarks" docs "ER-7: README with build steps, example session and benchmark results" \
'**Done when:** a new reader can build lobster and read the numbers without asking anything.'
mk "M5 Threads and benchmarks" docs "ER-8: DESIGN.md covers every major decision with its alternatives" \
'File format, block size, codecs, hash table, threading, error handling, and the no-NULL append-only choice.

**Done when:** each decision names the alternatives considered and why this one won.'

echo "done."
