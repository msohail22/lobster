# lobster

A single-machine columnar analytical engine in C++23, plus the C++ learning path
that goes with it.

- Owner: Mohammed Sohail
- Started: 2026-10-26
- Target length: about 12 weeks

This file is the single source of truth. Part 1 is the C++ learning path.
Part 2 is the functional spec. Part 3 is the milestone plan.

---

# Part 1 — C++ learning path

Read the page, then write a small program in the experiments repo to test the
idea. cppreference is the main language reference.

## Phase 1: Core language (months 1-2)

| Topic | Why | Docs |
|---|---|---|
| Object lifetime and storage duration | When objects are created and destroyed | [lifetime](https://en.cppreference.com/w/cpp/language/lifetime) |
| RAII | The base of all resource handling in C++ | [RAII](https://en.cppreference.com/w/cpp/language/raii) |
| Rule of three / five / zero | When to write copy and move functions | [rule of three](https://en.cppreference.com/w/cpp/language/rule_of_three) |
| Value categories (lvalue, rvalue, xvalue) | Needed to understand moves | [value categories](https://en.cppreference.com/w/cpp/language/value_category) |
| Move semantics | Move without copy | [move ctor](https://en.cppreference.com/w/cpp/language/move_constructor), [move assign](https://en.cppreference.com/w/cpp/language/move_assignment) |
| Smart pointers | `unique_ptr`, `shared_ptr` | [memory](https://en.cppreference.com/w/cpp/memory) |
| References, `const`, `string_view`, `span` | Passing data without copies | [string_view](https://en.cppreference.com/w/cpp/string/basic_string_view), [span](https://en.cppreference.com/w/cpp/container/span) |
| Undefined behaviour | What it is, why it breaks optimized code | [UB](https://en.cppreference.com/w/cpp/language/ub) |
| Containers and algorithms | `vector` internals, iterator invalidation | [containers](https://en.cppreference.com/w/cpp/container), [algorithms](https://en.cppreference.com/w/cpp/algorithm) |
| Error handling | Exceptions vs `std::expected` | [exceptions](https://en.cppreference.com/w/cpp/language/exceptions), [expected](https://en.cppreference.com/w/cpp/utility/expected) |

## Phase 2: Generic code (months 2-3)

| Topic | Why | Docs |
|---|---|---|
| Templates (class, function, specialization) | Generic code | [templates](https://en.cppreference.com/w/cpp/language/templates) |
| `constexpr` and `if constexpr` | Compile-time work, type-based branching | [constexpr](https://en.cppreference.com/w/cpp/language/constexpr), [if](https://en.cppreference.com/w/cpp/language/if) |
| Concepts | Constrain templates, get clear errors | [constraints](https://en.cppreference.com/w/cpp/language/constraints) |
| Variadic templates | Variable argument lists | [parameter packs](https://en.cppreference.com/w/cpp/language/parameter_pack) |
| Virtual functions and object layout | vtables, dynamic dispatch vs templates | [virtual](https://en.cppreference.com/w/cpp/language/virtual) |
| Ranges (read, use lightly) | Composable views | [ranges](https://en.cppreference.com/w/cpp/ranges) |

## Phase 3: Performance and memory (months 3-5, with lobster)

| Topic | Why | Docs |
|---|---|---|
| Alignment and `alignas` | Control memory layout | [alignas](https://en.cppreference.com/w/cpp/language/alignas) |
| Type punning with `bit_cast` | Reinterpret bytes safely | [bit_cast](https://en.cppreference.com/w/cpp/numeric/bit_cast) |
| Custom allocators and arenas | Cut allocation cost | [polymorphic_allocator](https://en.cppreference.com/w/cpp/memory/polymorphic_allocator), [monotonic_buffer_resource](https://en.cppreference.com/w/cpp/memory/monotonic_buffer_resource) |
| SIMD intrinsics (SSE4.2, AVX2) | Many values per instruction | [Intel Intrinsics Guide](https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html) |
| Auto-vectorization | See what the compiler generates | [Compiler Explorer](https://godbolt.org) |
| Profiling | Find the real hot spot | [perf examples](https://www.brendangregg.com/perf.html), [flame graphs](https://www.brendangregg.com/flamegraphs.html) |

## Phase 4: Concurrency (months 4-5, with lobster threads)

| Topic | Why | Docs |
|---|---|---|
| Threads, mutexes, condition variables | The basic tools | [thread support](https://en.cppreference.com/w/cpp/thread) |
| Memory model | What "data race" means formally | [memory model](https://en.cppreference.com/w/cpp/language/memory_model) |
| Atomics and memory ordering | Lock-free correctness | [atomic](https://en.cppreference.com/w/cpp/atomic/atomic), [memory_order](https://en.cppreference.com/w/cpp/atomic/memory_order) |
| False sharing | Why threads slow each other down | [hardware_destructive_interference_size](https://en.cppreference.com/w/cpp/thread/hardware_destructive_interference_size) |

## Tooling (learn alongside, as needed)

- CMake: [official tutorial](https://cmake.org/cmake/help/latest/guide/tutorial/index.html)
- GoogleTest: [primer](https://google.github.io/googletest/primer.html)
- Sanitizers: [AddressSanitizer](https://clang.llvm.org/docs/AddressSanitizer.html), [ThreadSanitizer](https://clang.llvm.org/docs/ThreadSanitizer.html)

## Style and ClickHouse-specific

- C++ Core Guidelines, sections on resources and interfaces: [Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)
- ClickHouse: [architecture overview](https://clickhouse.com/docs/development/architecture), [developer instructions](https://clickhouse.com/docs/development/developer-instruction)

---

# Part 2 — Functional requirements

## Purpose and scope

lobster is a single-machine columnar analytical engine in C++23. It imports CSV
data, stores it by column with compression, and runs a small SQL subset fast
enough to measure against DuckDB.

Three goals:

- Show professional C++ skill in a codebase of your own design.
- Teach database internals, OS and CPU performance through real problems.
- Produce measured, reproducible benchmark results you can explain in an interview.

How to use this spec: each requirement has an ID (for example FR-ST-3) and a
"Done when" test. The spec says what lobster must do, not how. File formats,
class design and algorithms are your decisions. Record each one in `DESIGN.md`
with its trade-off.

## User interface

lobster runs as an interactive shell, similar to the ClickHouse client.

```
$ lobster --data-dir ./data
lobster> CREATE TABLE trips (pickup_day Int32, distance Float64, fare Float64, payment String);
lobster> COPY trips FROM 'trips.csv';
lobster> SELECT payment, COUNT(*), AVG(fare) FROM trips WHERE distance > 5 GROUP BY payment ORDER BY 2 DESC LIMIT 10;
```

| ID | Requirement | Done when |
|---|---|---|
| FR-UI-1 | Start with `--data-dir <path>`. All tables live under that directory. | Two shells with different directories see different tables. |
| FR-UI-2 | Read one statement per line, ended by `;`. Exit on `exit`, `quit` or Ctrl-D. | Statements run one after another; Ctrl-D exits cleanly. |
| FR-UI-3 | Also run a single statement non-interactively: `lobster --data-dir ./data -q "SELECT ..."`. | The benchmark script can call lobster without the shell. |
| FR-UI-4 | Print results as an aligned text table with column names. | Output is readable for up to about 20 columns. |
| FR-UI-5 | After each query, print elapsed time, rows read and bytes read from disk. | Numbers show for every SELECT, like `10 rows. Elapsed: 0.214 s. Read 10.0M rows, 81 MB`. |
| FR-UI-6 | On error, print a clear message and keep the shell running. | A bad query never crashes or exits the shell. |

## Data types and table rules

Four types, append-only tables. No NULLs, no UPDATE, no DELETE.

| ID | Requirement | Done when |
|---|---|---|
| FR-DT-1 | Support `Int32`, `Int64`, `Float64` and `String` columns. | Each type round-trips from CSV to disk and back without change. |
| FR-DT-2 | Strings are UTF-8 bytes of any length. Comparisons are byte-wise. | A string with commas, quotes and non-ASCII text round-trips. |
| FR-DT-3 | NULL is not supported. An empty CSV field is an error for numeric columns and an empty string for `String`. | Import of an empty numeric field fails with the line number. |
| FR-DT-4 | Tables are append-only. A second COPY adds rows to the end. | Two imports of 1M rows give a table of 2M rows. |
| FR-DT-5 | Table and column names: letters, digits and `_`, starting with a letter. Names are case-sensitive. | Invalid names give an error at CREATE TABLE. |
| FR-DT-6 | `DROP TABLE name` deletes the table and its files. | The table directory is gone and the name can be reused. |

The "no NULL, append-only" choice is a design decision. Write it in
`DESIGN.md`: it keeps every column dense and removes a null bitmap from every
operator.

## Storage

Each table is a directory with one file per column, split into fixed-size
blocks with min/max statistics. Tables must survive restarts and may be larger
than RAM.

| ID | Requirement | Done when |
|---|---|---|
| FR-ST-1 | One directory per table under the data directory. One data file per column. | `ls data/trips/` shows one file per column plus metadata. |
| FR-ST-2 | A metadata file stores the schema, codec per column, row count and block count. | lobster restarts and lists the same tables with the same schemas. |
| FR-ST-3 | Rows are split into blocks of a fixed number of rows (default 8,192, configurable at CREATE TABLE). The last block may be smaller. | A table of 20,000 rows has 3 blocks. |
| FR-ST-4 | For each block and each column, store min and max values in an index file. | A test reads the index and checks min/max against the raw data. |
| FR-ST-5 | A query can read one block of one column without reading the other blocks. | Bytes read for a one-block query is close to one block's size. |
| FR-ST-6 | Scans read block by block. A whole column is never loaded into memory at once. | A query on a table 2x larger than RAM finishes without running out of memory. |
| FR-ST-7 | COPY writes are crash-safe: an interrupted import leaves the table as it was before the import. | Killing lobster during COPY and restarting gives the old row count. |

FR-ST-7 is a good place to learn `fsync` and write-then-rename. FR-ST-6 is
where you learn the page cache and mmap vs read.

## Compression

Each column has a codec, chosen at CREATE TABLE or set to a default. Each block
compresses on its own, so one block decompresses without the others.

```sql
CREATE TABLE trips (
  pickup_day Int32 CODEC(Delta, LZ4),
  fare Float64 CODEC(LZ4),
  payment String CODEC(Dict)
);
```

| ID | Requirement | Done when |
|---|---|---|
| FR-CO-1 | Codec `None`: raw values. | Baseline for all comparisons. |
| FR-CO-2 | Codec `LZ4`, using the LZ4 library. Default for all columns. | Round-trip tests pass on random and real data. |
| FR-CO-3 | Codec `Delta` for integer columns, your own implementation. Can chain with LZ4: `CODEC(Delta, LZ4)`. | Sorted integers compress better with Delta+LZ4 than with LZ4 alone. |
| FR-CO-4 | Codec `Dict` for String columns: store each distinct value once, replace values with small integer IDs. Your own implementation. | A column with 5 distinct values compresses more than 10x. |
| FR-CO-5 | Reject invalid codec choices, for example `Delta` on a `String`. | CREATE TABLE gives a clear error. |
| FR-CO-6 | `DESCRIBE trips` shows, per column: type, codec, uncompressed size, compressed size and ratio. | Output matches the sizes of files on disk. |
| FR-CO-7 | Corrupt compressed data is detected (a checksum per block) and gives an error, not a crash. | Flipping one byte in a column file gives a checksum error on query. |

## Query language

Six statements and a small SELECT. Write the parser yourself: tokenizer, then
recursive descent to an AST. No parser generators.

Statements: `CREATE TABLE`, `DROP TABLE`, `COPY ... FROM`, `DESCRIBE`,
`SHOW TABLES`, `SELECT`.

| ID | Requirement | Done when |
|---|---|---|
| FR-QL-1 | SELECT a list of columns, or `*`. | `SELECT fare, payment FROM trips LIMIT 5` works. |
| FR-QL-2 | Aggregates: `COUNT(*)`, `COUNT(col)`, `SUM`, `AVG`, `MIN`, `MAX`. Column aliases with `AS`. | Each aggregate matches DuckDB on test data. |
| FR-QL-3 | WHERE with `=` `!=` `<` `<=` `>` `>=` comparing a column to a literal, combined with `AND`, `OR`, `NOT` and parentheses. | `WHERE (distance > 5 OR fare > 50) AND payment = 'card'` works. |
| FR-QL-4 | `GROUP BY` one or more columns. Every non-aggregate column in SELECT must be in GROUP BY. | Invalid mixes give a clear error. |
| FR-QL-5 | `ORDER BY` column, alias or position, `ASC` or `DESC`, multiple keys. | `ORDER BY 2 DESC, payment` works. |
| FR-QL-6 | `LIMIT n`. | Only n rows print. |
| FR-QL-7 | Keywords are case-insensitive; string literals use single quotes. | `select count(*) from trips` works. |
| FR-QL-8 | Errors name the problem and the position: unknown table, unknown column, type mismatch, syntax error. | `SELECT fare FROM trips WHERE fare > 'abc'` gives a type error, not a crash. |
| FR-QL-9 | `EXPLAIN SELECT ...` prints the plan: operators in order and how many blocks the min/max index will skip. | Output shows the pipeline for any valid query. |

Out of this subset on purpose: joins, subqueries, HAVING, arithmetic
expressions, functions other than the aggregates above.

## Execution engine

Queries run as a pipeline of operators that pass blocks of column values, not
single rows. Stage order:

1. **Scan**: read and decompress only the columns the query needs.
2. **Filter**: apply WHERE and keep matching positions.
3. **Aggregate**: compute GROUP BY and aggregates.
4. **Sort and limit**: apply ORDER BY and LIMIT.
5. **Output**: format the result.

| ID | Requirement | Done when |
|---|---|---|
| FR-EX-1 | Operators process one block of column values at a time (vectorized), not one row at a time. | The hot loops in perf are tight loops over arrays. |
| FR-EX-2 | Scan reads only the columns used in SELECT, WHERE, GROUP BY and ORDER BY. | Bytes read for `SELECT SUM(fare)` equals the fare column size only. |
| FR-EX-3 | Skip blocks where the min/max index shows no row can match WHERE. | On data sorted by `pickup_day`, a one-day filter reads under 5% of blocks. |
| FR-EX-4 | GROUP BY uses a hash table you design (open addressing recommended, your choice). | Handles 10M distinct keys without errors; design documented in `DESIGN.md`. |
| FR-EX-5 | Multithreaded scan, filter and aggregate: each thread works on its own blocks and builds a partial result; partials merge at the end. Thread count set with `--threads N` (default: CPU cores). | Results are the same for 1 and N threads. |
| FR-EX-6 | `ORDER BY ... LIMIT n` keeps only the top n rows during sorting (a heap), not a full sort. | `LIMIT 10` on 10M groups uses far less memory than a full sort. |
| FR-EX-7 | A row-at-a-time baseline mode (`--engine=row`) that runs the same queries without vectorization. | Benchmarks can compare both modes on the same query. |

FR-EX-7 gives the "before" number for every "after" number in the benchmarks.

## Correctness and testing

Every result lobster prints must match DuckDB on the same data. Fast but wrong
results make every benchmark worthless.

| ID | Requirement | Done when |
|---|---|---|
| FR-TE-1 | Unit tests (GoogleTest) for each codec, the tokenizer, the parser, the hash table and each operator. | `ctest` runs all of them in under a minute. |
| FR-TE-2 | Codec round-trip tests on edge cases: empty block, one value, all same values, min and max of each type, random data. | All pass. |
| FR-TE-3 | A query test suite of at least 50 queries in a text file, covering every FR-QL requirement. | The file exists and runs in CI. |
| FR-TE-4 | A script loads the same CSV into DuckDB, runs each test query in both, and compares results (floats within a small tolerance). | Every query matches. |
| FR-TE-5 | Thread-safety check: the full query suite passes with ThreadSanitizer. | No TSan reports. |
| FR-TE-6 | Memory check: the full test suite passes with AddressSanitizer and UBSan. | No ASan or UBSan reports. |
| FR-TE-7 | Fuzz the parser with random and malformed input (libFuzzer or a simple random generator). | One hour of fuzzing gives no crash. |

## Benchmarks

Benchmarks are the main output of this project. Each published number must be
reproducible with one command and explained with a profile.

| ID | Requirement | Done when |
|---|---|---|
| FR-BM-1 | Dataset: a fixed sample of the ClickBench hits dataset (for example 10M rows) plus one synthetic dataset generated with a fixed seed. | A script downloads or generates both the same way every time. |
| FR-BM-2 | A fixed query set of 10-15 queries: full scans, selective filters, low- and high-cardinality GROUP BY, and `ORDER BY ... LIMIT`. | The queries live in the repo as files. |
| FR-BM-3 | One command runs everything: `./bench/run.sh`. Each query runs 1 cold (page cache dropped) and 5 warm times; report the median. | Two runs on the same machine differ by under 10%. |
| FR-BM-4 | Compare: lobster vectorized vs `lobster --engine=row` vs DuckDB, on the same data and machine. | A results table in the README. |
| FR-BM-5 | Compare codecs: compression ratio and decompression speed (MB/s) per codec on real columns. | A codec table in the README. |
| FR-BM-6 | Thread scaling: run the query set at 1, 2, 4 and N threads. | A scaling chart in the README, with an explanation of where it stops scaling. |
| FR-BM-7 | Record the environment with every result: CPU, RAM, disk, OS, compiler, flags and commit hash. | Each results file has this header. |
| FR-BM-8 | At least two flame graphs (perf) with a written explanation: what was slow, what changed, the before and after numbers. | Two write-ups in `bench/README.md`, ready to reuse as blog posts. |

Benchmark builds always use `RelWithDebInfo` or `Release`, never Debug and
never with sanitizers.

## Engineering requirements

| ID | Requirement |
|---|---|
| ER-1 | C++23, built with CMake. Builds with both GCC and Clang without warnings at `-Wall -Wextra`. |
| ER-2 | Dependencies: LZ4 and GoogleTest only (plus DuckDB as an external tool for testing). Everything else is your own code. |
| ER-3 | Debug, release and sanitizer builds are each one command (CMake presets, or documented commands). |
| ER-4 | GitHub Actions CI on every push: build with GCC and Clang, unit tests, sanitizer run, DuckDB comparison. |
| ER-5 | `.clang-format` and `compile_commands.json` export, so formatting and clangd work the same everywhere. |
| ER-6 | Errors use one consistent approach (exceptions or `std::expected`, your choice), recorded in `DESIGN.md`. |
| ER-7 | `README.md`: what lobster is, how to build, an example session, the benchmark tables and charts. |
| ER-8 | `DESIGN.md`: every major decision (file format, block size, codecs, hash table, threading, error handling) with the alternatives considered and why. |

## Out of scope

These stay out until every requirement above is done. Each one adds weeks and
teaches less than doing the core well.

- Joins (one hash join is the only stretch goal, after everything else is done)
- Transactions, NULLs, UPDATE and DELETE
- Indexes other than per-block min/max
- A network server or client protocol
- Distributed or multi-machine queries
- Arithmetic expressions, string functions, subqueries, HAVING
- A query optimizer beyond column pruning and block skipping

---

# Part 3 — Milestones

Build in this order, about 12 weeks in total. Each milestone ends with working,
tested code and one short write-up for low-level-lab.

## M1: Skeleton and storage (weeks 1-2)

- [ ] Repo setup: CMake, GoogleTest, CI, `.clang-format` (ER-1 to ER-5)
- [ ] Shell and non-interactive mode (FR-UI-1 to FR-UI-3, FR-UI-6)
- [ ] Types, CREATE TABLE, COPY, DROP TABLE (FR-DT-1 to FR-DT-6)
- [ ] Column files, metadata, blocks, restart (FR-ST-1 to FR-ST-3)

## M2: Compression (weeks 3-4)

- [ ] Codecs None, LZ4, Delta, Dict, with checksums (FR-CO-1 to FR-CO-7)
- [ ] Codec round-trip tests (FR-TE-2)
- [ ] Codec benchmark table (FR-BM-5)

## M3: Parser and basic queries (weeks 5-6)

- [ ] Tokenizer, parser, AST, errors (FR-QL-1 to FR-QL-8)
- [ ] Row-at-a-time engine first (FR-EX-7), with result printing (FR-UI-4, FR-UI-5)
- [ ] DuckDB comparison script and first 50 test queries (FR-TE-3, FR-TE-4)

## M4: Vectorized engine (weeks 7-9)

- [ ] Vectorized scan, filter, aggregate, sort/limit (FR-EX-1, FR-EX-2, FR-EX-4, FR-EX-6)
- [ ] Min/max index and block skipping (FR-ST-4, FR-ST-5, FR-EX-3)
- [ ] Larger-than-RAM scans and crash-safe import (FR-ST-6, FR-ST-7)
- [ ] EXPLAIN (FR-QL-9)

## M5: Threads and benchmarks (weeks 10-12)

- [ ] Multithreaded execution (FR-EX-5) and TSan clean (FR-TE-5)
- [ ] Full benchmark suite and README results (FR-BM-1 to FR-BM-4, FR-BM-6, FR-BM-7)
- [ ] Two flame-graph write-ups (FR-BM-8)
- [ ] Sanitizers and fuzzing clean (FR-TE-6, FR-TE-7)
- [ ] `DESIGN.md` complete (ER-8)

Done means every box is ticked and CI is green. Building the row-at-a-time
engine first in M3 is deliberate: it gives correct results to test against and
the baseline numbers for M4.
