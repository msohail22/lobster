<div align="center">
  <img src="assets/lobster.svg" width="160" alt="lobster logo" />
  <h1>lobster</h1>
  <p><b>An in-memory key-value store in C++23.</b></p>
  <p>Built three ways, to measure what shard-per-core actually buys.</p>
</div>

---

`GET` and `SET`, memcached text protocol, over UDP. The feature set is
deliberately tiny so the work lands on the network and memory path.

The same store, three thread models:

| | Design |
|---|---|
| **A** | one shared hash table behind striped mutexes |
| **B** | shard per core — one pinned thread, its own table slice, an SPSC ring mesh between cores |
| **C** | Design B, with one `io_uring` ring per core |

Design A exists to be beaten. Without it, "share-nothing is faster" is an
assumption rather than a number.

**Status:** planning done, no code yet. The roadmap, the measurement rules and
the hardware this runs on are in [PLAN.md](PLAN.md).

## Build

```sh
cmake -B build
cmake --build build
./build/lobster
```

## Test

```sh
ctest --test-dir build
```

## License

MIT. See [LICENSE](LICENSE).
