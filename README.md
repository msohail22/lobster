<div align="center">
  <img src="assets/lobster.svg" width="160" alt="lobster logo" />
  <h1>lobster</h1>
  <p><b>Low-latency networking in C++.</b></p>
</div>

---

A learning project: an in-memory key-value store - memcached, rewritten the
way a trading system would be written. Shard per core, kernel bypass, and a
latency number recorded at every step. The roadmap lives in [PLAN.md](PLAN.md).

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
