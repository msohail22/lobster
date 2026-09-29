# Project Guide: DPDK Flow Meter → ClickHouse

> How to use this file: give it to an AI tutor and say *"Teach me step N. Don't write my code — explain,
> quiz me, and review what I write."* All code is written by hand.

## 1. What is this, in plain words?

A **flow** is one conversation between two computers (your laptop ↔ a YouTube server).
A **flow meter** watches network packets and, instead of saving every packet, keeps **one summary row per conversation**:

| src_ip | dst_ip | src_port | dst_port | proto | packets | bytes | first_seen | last_seen |
|---|---|---|---|---|---|---|---|---|
| 10.0.0.5 | 142.250.1.1 | 51234 | 443 | TCP | 1820 | 2100000 | 10:00:01 | 10:00:09 |

A million packets → a few thousand rows. That shrinking step is the whole point.

The program:
1. **Reads packets** with DPDK (fast, userspace packet I/O).
2. **Groups them into flows** in a hash table keyed by the 5-tuple (src IP, dst IP, src port, dst port, protocol).
3. **Closes a flow** when it has been idle for N seconds.
4. **Sends closed flows to ClickHouse** in big batches.

**Why ClickHouse users care:** network teams store flows in ClickHouse to answer "who uses the most bandwidth?",
"is someone attacking us?", "how much traffic per customer?". Tools like Akvorado store flows in ClickHouse, but
they only *collect* flow records that routers export. This tool *creates* flows directly from packets.

## 2. C or C++?

**C++ (C++20).** DPDK is a C library, so you call its C functions — but wrap them in small C++ classes:

- **RAII:** a `Mempool` class frees its `rte_mempool` in the destructor. No leaks, no manual cleanup.
- **Templates:** `FlowTable<Key, Value>`.
- **`std::atomic`** for counters shared between threads.
- **`std::span`** to pass packet batches without copying.

You get to learn DPDK *and* modern C++. Plain C would teach you DPDK but not the C++ that jobs ask about.

Rule: **no exceptions and no `new`/`malloc` in the packet loop.** Allocate everything at startup.

## 3. What you need

- A Linux machine. **No special network card needed.**
- DPDK (`sudo pacman -S dpdk`, or build from source with `meson` + `ninja`).
- ClickHouse in Docker: `docker run -d -p 8123:8123 --name ch clickhouse/clickhouse-server`
- A C++20 compiler + CMake.
- Test traffic: record your own with `sudo tcpdump -i any -w test.pcap`, or download samples
  from Wireshark's "SampleCaptures" wiki page.

Hugepages (DPDK needs them):
```sh
echo 1024 | sudo tee /proc/sys/vm/nr_hugepages
```

**Fake network cards (virtual devices):**

| Device flag | What it does | Use for |
|---|---|---|
| `--vdev=net_pcap0,rx_pcap=test.pcap` | reads packets from a file | development, repeatable tests |
| `--vdev=net_af_packet0,iface=wlan0` | reads a real Linux interface | live traffic |
| `--vdev=net_null0` | infinite fake packets | measuring max speed of your code |

Honest limit: without a real NIC you can't show DPDK's kernel bypass at 10 Gbps. You *can* measure how fast your
pipeline is and prove it's correct. The same code runs on a real card later (e.g. used Intel X520, ~$30) — only the flag changes.

## 4. Scope (keep it small)

**Core (must finish):** one thread, pcap in → flows → ClickHouse → SQL query works.
**Bonus (only after core is done):** multiple threads, live interface, benchmarks.

Finishing the core beats half-building the bonus.

## 5. Steps

### Step 1 — Hello DPDK (week 1)
- Set up hugepages, build DPDK's `examples/skeleton`.
- Run it with `--vdev=net_pcap0,rx_pcap=test.pcap`.
- ✅ Done when: it prints how many packets it received.

**Learn:** EAL (`rte_eal_init`), ports, RX queues, `rte_eth_rx_burst`, mbufs, mempools.

### Step 2 — Parse packets (week 1–2)
- Your own program: for each mbuf, read Ethernet → IPv4/IPv6 → TCP/UDP headers.
- Handle VLAN tags. Skip anything you don't understand (count it as "other").
- ✅ Done when: packet counts per protocol match `tcpdump -r test.pcap | wc -l` style checks.

**Learn:** `rte_pktmbuf_mtod`, header structs (`rte_ether_hdr`, `rte_ipv4_hdr`, `rte_tcp_hdr`), byte order (`rte_be_to_cpu_16`).

### Step 3 — Flow table (week 2–3)
- Key = 5-tuple. Value = packets, bytes, first_seen, last_seen, TCP flags.
- Use `rte_hash` first. (Bonus later: write your own open-addressing table and compare.)
- Every second, scan for flows idle > 15 s, move them to an "expired" list.
- ✅ Done when: total bytes across all flows == total bytes in the pcap.

**Learn:** hashing, pre-sized tables, why you never allocate per packet.

### Step 4 — Send to ClickHouse (week 3–4)
Create the table:
```sql
CREATE TABLE flows
(
    src_ip IPv6, dst_ip IPv6,          -- store IPv4 as IPv4-mapped IPv6
    src_port UInt16, dst_port UInt16,
    proto UInt8,
    packets UInt64, bytes UInt64,
    first_seen DateTime64(3), last_seen DateTime64(3)
)
ENGINE = MergeTree
ORDER BY (first_seen, src_ip, dst_ip)
TTL toDateTime(first_seen) + INTERVAL 30 DAY;
```
- Batch expired flows (e.g. every 10 000 rows or every 1 s, whichever first).
- Send with HTTP POST to `http://localhost:8123/?query=INSERT%20INTO%20flows%20FORMAT%20RowBinary`.
  Write the `RowBinary` bytes yourself — values back to back, no separators:
  integers little-endian, `IPv6` as its 16 raw bytes in network order, `DateTime64(3)` as an `Int64` of milliseconds.
- Use a plain socket or libcurl — **no DPDK on this side.**
- ✅ Done when: this query works:
```sql
SELECT dst_ip, sum(bytes) AS total FROM flows GROUP BY dst_ip ORDER BY total DESC LIMIT 10;
```

**Learn:** RowBinary format, why ClickHouse wants few big inserts (not one per row).

**🎉 Core project finished here.** Push it to GitHub with a README and a screenshot of the query.

### Bonus A — Multiple threads (week 5–8)
- N worker lcores each own a flow table (no locks).
- Workers push expired flows into an `rte_ring` → one exporter thread sends to ClickHouse.
- If the ring is full: **drop and count**, never block the packet loop.
- With a single-queue fake device, one RX thread spreads packets to workers via rings, hashed by 5-tuple
  (both directions of a flow must go to the same worker — sort the two IPs/ports before hashing).

**Learn:** lcores, `rte_ring`, lock-free queues, `std::atomic` memory ordering, false sharing.

### Bonus B — Measure (week 9+)
- With `net_null` and pcap replay: packets/second, flows/second, rows/second inserted, drops.
- Profile with `perf record` / `perf report`. Fix the top hotspot, measure again.
- Write a short blog post: design, numbers, what you learned.

## 6. What to read

**DPDK** (doc.dpdk.org):
- Getting Started Guide for Linux
- Programmer's Guide: EAL, Mbuf Library, Mempool Library, Ring Library, Hash Library, Poll Mode Driver
- Sample apps: `skeleton`, then `l2fwd`, then `l3fwd`

**ClickHouse** (clickhouse.com/docs):
- HTTP interface
- `RowBinary` format
- "Selecting an insert strategy" (why batching matters)
- Data types: `IPv6`, `DateTime64`, `LowCardinality`

## 7. Questions to be able to answer (interview prep)

1. Why does DPDK poll instead of using interrupts?
2. What is an mbuf and why are they pre-allocated in a mempool?
3. Why does each worker own its own flow table instead of sharing one?
4. What happens when the ring to the exporter is full? Why drop instead of wait?
5. Why batch inserts to ClickHouse instead of one row per flow?
6. How do you prove no bytes were lost between the pcap and ClickHouse?
7. Where did `perf` say the time goes, and what did you change?

## 8. Rules for yourself

- Write every line by hand. Use AI only to **explain** and to **review code you already wrote**.
- After each step, delete one line of your code and check a test catches it.
- Finish the core before touching any bonus.
