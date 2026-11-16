# lobster

*A plan, and the reasoning behind it.*

Last updated 2026-11-16.

---

## Contents

1. [The idea](#1-the-idea)
2. [The machine, and what it forbids](#2-the-machine-and-what-it-forbids)
3. [The language](#3-the-language)
4. [The eight weeks](#4-the-eight-weeks)
5. [Why anyone should care — the hiring evidence](#5-why-anyone-should-care)
6. [The rules](#6-the-rules)
7. [The topics](#7-the-topics)
8. [The long game — milestones M0 to M16](#8-the-long-game)
9. [What it costs — time and code](#9-what-it-costs)
10. [How it is built — dependencies, layout, scaffolding](#10-how-it-is-built)
11. [Open questions](#11-open-questions)

---

# 1. The idea

Build an in-memory key-value store. Two commands, `GET` and `SET`, over UDP,
speaking the memcached text protocol. Nothing else, ever.

Then build it **three times**, and measure which one is faster.

```
Design A   one shared hash table behind striped mutexes
Design B   shard per core: one pinned thread, its own slice of the table,
           its own listener, an SPSC ring mesh between cores
Design C   Design B, but each core gets its own io_uring ring
```

That is the whole project. It sounds small because it is small. The point is
not the cache.

## Why a cache at all

Because `GET` is the shortest honest unit of work anyone has invented:

```
packet arrives → parse 20 bytes → hash a key → one memory lookup → reply
```

There is nowhere for the time to hide. No disk, no algorithm, no computation.
So when p99.9 comes back at 40 µs instead of 2 µs, the cause is certainly one
of five things: the kernel, the NIC, a cache miss, a NUMA hop, or the
scheduler. You can find out which. In a bigger program you cannot.

You cannot study your reaction time while juggling. You study it by pressing
one button. `GET` is the button.

## Why three designs and not one

Because one design proves nothing.

"Shard-per-core is faster than a shared table" is a thing everyone says. It
is in every Seastar talk and every ScyllaDB blog post. Build only the fast
version and you have repeated the claim. Build the slow one first, measure
it, then beat it, and you have *made* the claim.

**Design A exists to be beaten.** It is a week of work whose entire purpose
is to be the number in the left-hand column. That week is not overhead; it is
the experiment.

## What the project actually is, then

A latency project wearing a cache as a costume. A cache is simply the
simplest thing that still needs all three of a network, a data structure and
a thread model at the same time — which is what makes it a place where you
can learn anything at all.

## Fixed scope

**In:** `GET` and `SET`. memcached text protocol. UDP. Loopback.

**Out, permanently:** lists, sets, counters, TTL semantics beyond a plain
expiry, clustering, replication, durability guarantees.

The feature set is deliberately tiny so that the effort lands on the topics
in section 7, not on features. Every time this document is tempted toward a
feature, that is the sentence to re-read.

## Where it stands today

Empty. `src/main.cpp` prints a line and exits. Everything in this document is
still to do.

---

# 2. The machine, and what it forbids

Everything below was measured on 2026-11-12, not remembered. This matters
more than it usually would, because this machine rules out about a third of
what a plan like this would normally contain.

```
CPU       AMD Ryzen 5 5500U, Zen 2, 6 cores / 12 threads, 1 socket
          AVX2 yes, AVX-512 no. constant_tsc + nonstop_tsc.
          cat_l3, mba, rdt_a present — cache allocation works on AMD.
L3        2 × 4 MB, NOT one shared block
NUMA      1 node
RAM       7 GB total, about 3 GB available
Kernel    7.2.15-1-omarchy
          CONFIG_XDP_SOCKETS=y, CONFIG_NO_HZ_FULL=y,
          CONFIG_CPU_ISOLATION=y, CONFIG_X86_CPU_RESCTRL=y
          No isolcpus and no nohz_full on the current command line
Idle      acpi_idle driver (POLL, C1, C2, C3) — NOT intel_idle
Governor  acpi-cpufreq, schedutil, boost on
NIC       wlp2s0, iwlwifi. THE ONLY NIC. No Ethernet port.
PTP       /dev/ptp0 exists but is iwlwifi-PTP, useless at microseconds
Hugepages HugePages_Total = 0, pdpe1gb present, THP = always
Toolchain GCC 16.2.1, Clang 23.1.3, both build -std=c++26. C++23 is set.
```

Read that as three sentences:

**There is one network card and it is WiFi.** So there is no RSS, no DPDK, no
hardware timestamping, and no real kernel bypass. Four milestones in section
8 are marked `BLOCKED` because of this single line. They are not deleted —
the reasoning in them is still correct, and a second machine with a wired
Intel NIC would unblock them tomorrow.

**There is one NUMA node.** So remote-memory cost cannot be observed at all.
The NUMA code gets written correctly, with `hwloc` and `libnuma`, and then
nothing is learned from running it. That is an honest outcome and it is
recorded as one.

**Six cores must hold the server, the load generator and the desktop.** Two
shards, not four, in every experiment in this document. Any number produced
here is a *relative* A/B, never an absolute, because the client and the
server are fighting over the same cache.

One more consequence, and it is the one that quietly shapes the whole
schedule: **the kernel UDP round trip on loopback costs roughly 10 µs, and
the hash table costs roughly 100 ns.** An end-to-end measurement therefore
cannot see the data structure at all — the signal is one part in a hundred.
This is why there is an in-process microbenchmark in week 3 and why the week
ordering looks the way it does.

---

# 3. The language

**C++, C++23, Clang.** Decided 2026-11-12, not to be revisited.

Four reasons, in order of how much they matter:

1. **`std::atomic` with an explicit memory model.** Week 6 is a hand-written
   SPSC queue. Without a specified memory model that week is guesswork.
2. **Templates make the comparisons free.** Weeks 4 to 7 compare three thread
   models and several queue types. One benchmark harness templated over the
   type, rather than three copies of it that drift apart.
3. **`std::start_lifetime_as`.** It makes casting a received packet buffer to
   a struct legal rather than technically undefined. C has no equivalent.
4. **It is the language of the field this points at.** Not a technical
   argument, but an honest one.

And the cost, stated plainly: **C++ makes it easy to be accidentally slow.**
`std::string`, `std::function`, `shared_ptr`, a range view inside a loop —
each quietly adds an allocation or an indirect call and never complains. C
cannot betray you that way.

The discipline that answers this is simple and it is a rule, not a
preference: **the hot path is written as "C with templates".** No allocation,
no virtual calls, no exceptions, no standard containers. The comfortable C++
— RAII, `std::expected`, ranges, `std::print` — lives in startup, config,
tests and the load generator, and never crosses into a `GET`.

Expect C-shaped code inside `.cpp` files from week 7 onward, wrapped thinly
and not prettified, because `liburing` is a C API.

---

# 4. The eight weeks

**64 hours. Eight weeks, eight hours a week.** Set 2026-11-12.

This is the part that is actually committed. Section 8 contains the full v1
roadmap of 24 milestones, M0 to M13b plus M16. It is 26 to 38 weeks, so it
does not fit in these 64 hours. What follows was chosen for **learning per hour**, not for
completeness.

## The one concept being demonstrated

**Shard-per-core, share-nothing.** One pinned thread per core, each owning
its own slice of the hash table, talking to other cores only through
hand-written lock-free SPSC queues, with `io_uring` as each core's I/O
backend. This is the Seastar model.

It was chosen over kernel bypass, over AF_XDP and over `io_uring` alone
because it is the only candidate that is both buildable on this hardware and
forces the two things employers actually name: lock-free queues with explicit
memory ordering, and a named kernel I/O interface. Section 5 has the
evidence, including the part where the evidence is weaker than one would
like.

## The schedule

| Week | Hours | What gets built | What exists at the end |
|---|---|---|---|
| **1** | 8 | Single-thread `epoll` server, `GET` and `SET`, `std::unordered_map`. Build scaffolding: `lobster_core` library, GTest wired, the hanging smoke test fixed | a server that answers |
| **2** | 10 | Open-loop UDP load generator, recording latency from the *intended* send time. About 400 lines | a client that measures honestly |
| **3** | 8 | `clock_gettime` vs `rdtsc`, TSC invariance confirmed, HdrHistogram wired. A/A noise floor, three runs. `env.sh` with a check mode | the first trustworthy row in NUMBERS.md |
| **4** | 8 | **Design A.** Multi-thread, one shared table behind striped mutexes, then a spinlock with backoff | the baseline to beat |
| **5** | 10 | **Design B.** Own hash table — open addressing, 64-byte buckets, SoA. Shard per core with pinned threads and `SO_REUSEPORT`. Key-derived source port | a sharded store |
| **6** | 10 | Hand-written **SPSC ring mesh** for the keys the port trick cannot place. Padded with `std::hardware_destructive_interference_size`. TSan clean. False sharing measured with the padding present *and* removed | the hardest and most asked-about part |
| **7** | 8 | **Design C.** One `io_uring` ring per core, single issuer, `DEFER_TASKRUN`, multishot recv. A/B against `epoll`. Then `perf stat` and `perf c2c` across all three designs | the three-way comparison |
| **8** | 6 | Write up NUMBERS.md and the README as one continuous story | the artifact |

That is 64 hours. Weeks 2, 5 and 6 are deliberately over budget and week 8
deliberately under, because the load generator and the SPSC queue always
overrun, and the last week is writing rather than coding.

## Why this order

Five decisions, each of which looks wrong until you have been burned by it:

**The load generator comes second, not sixth.** Without an open-loop
generator every number after it is a lie by coordinated omission — a
closed-loop client stops sending while the server is stalled, and therefore
never records the stall. The measuring instrument has to exist before there
is anything worth measuring.

**The governor and the noise floor come before any optimisation.** Week 3
produces no feature at all. It fixes the CPU frequency, disables the deep
idle states, pins the THP setting, and then measures the same binary against
itself three times to find out how much two identical runs differ. Skipping
that week is how a project accumulates thirty rows of noise and a confident
wrong conclusion.

**Design A comes before Design B.** Covered above: the comparison *is* the
result.

**The SPSC queue gets a whole week to itself.** It is the single most
interview-cited topic in this document and the easiest to get subtly wrong —
a relaxed store where a release store belongs will pass every test on x86 and
fail on ARM.

**`io_uring` comes last.** A PVLDB 2026 paper measured a drop-in `epoll` →
`io_uring` swap at only **1.10×** and concluded that treating it as a
drop-in replacement "is inadequate"; it only pays off in a ring-per-thread,
single-issuer design. Which is to say: the architecture has to exist first,
or the result is a shrug.

## What the eight weeks produce

A README with five things on it. These five, and not a feature list, because
these five are what a conversation can be had about:

1. Throughput against server core count, 1 to 4, for all three designs.
2. p99 and p99.9 at a fixed offered rate, for all three designs.
3. `perf stat` counters per design — cache misses, context switches, IPC.
4. One **`perf c2c`** before and after, showing a false-sharing problem found
   and removed.
5. A **TSan-clean** SPSC queue, with tests.

## The honest limits, which go in the README too

Nothing here is hidden, because hiding it is how a project stops being
believable:

- Everything runs over loopback, client and server sharing six cores. Every
  number is a relative A/B and never an absolute.
- The `io_uring` versus `epoll` gap on loopback **may turn out to be small**.
  That is a finding, not a failure, and the README says so with the PVLDB
  number next to it.
- Zero-copy receive and NAPI busy-poll cannot be demonstrated at all. Both
  need NIC support this machine does not have.
- One NUMA node, so the NUMA placement code is written correctly and never
  measured.

## What is cut, and what that costs

| Cut | What is lost |
|---|---|
| **M4** slab allocator | variable-length value management. Values are fixed-size for these eight weeks |
| **M7** zero-copy parse | `std::start_lifetime_as` and the no-allocation parse path |
| **M5** hugepages | TLB behaviour goes unexamined |
| **M6** prefetch and batching | overlapping memory trips, `recvmmsg` |
| **M8** boot-time isolation | `isolcpus` and `nohz_full` need a reboot. The no-reboot half survives in week 3 |
| **M1** conformance oracle | correctness checked by hand rather than diffed against real `memcached` |
| **M9, M9b** | the SMT and container studies |
| **M33** | the full utilisation curve, reduced to finding the knee once in week 3 |

v2 — AF_XDP, DPDK, SIMD, TCP, eviction, persistence — is not cut from these
eight weeks; it was removed from the project entirely on 2026-11-16.

The eight weeks tick **about 26 topics**. That is the price of
eight weeks. It is written here so that it is a decision taken in advance
rather than a disappointment discovered in week 7.

## The 26 topics these eight weeks tick

Named explicitly, so there is no vagueness about what gets a tick when a week
ends. The full list is linked from section 7.

**CPU and memory (6)** — cache lines and false sharing, measured with `perf
c2c` in week 6; cache-aware data layout; memory ordering, barriers and
`std::atomic`; store buffers and memory disambiguation; data-oriented design,
AoS versus SoA; frequency scaling, turbo and throttling.

**Concurrency (7)** — lock-free algorithms; SPSC, MPSC and MPMC queues;
seqlocks, on Design A; spinlocks, backoff and futexes; thread affinity,
pinning and isolation; shard per core, share nothing; the ABA problem and CAS
loops, on Design A's free list.

**Kernel and I/O (5)** — syscall cost and the vDSO; `epoll` and event loops;
`io_uring`; scheduler classes, `isolcpus` and `nohz_full`; C-states and
P-states, through `/dev/cpu_dma_latency`.

**Networking (2)** — consistent hashing and flow affinity; protocol framing.

**Measurement (6)** — `rdtsc` and `clock_gettime`; latency distributions,
p99.9 and coordinated omission; HdrHistogram; `perf` and hardware counters;
microbenchmarking pitfalls; queueing theory and Little's law, from week 3's
utilisation curve.

## Rules for the eight weeks specifically

- **A week that overruns loses its next item, not its measurement.** Drop
  scope. Never drop the NUMBERS.md row.
- **Weeks 2, 3 and 4 are not negotiable.** The load generator, the honest
  clock, the noise floor, the environment script and Design A are the
  difference between a project with results and a project with anecdotes. If
  time runs out, **cut Design C** — two designs compared honestly beats three
  compared badly.
- **No new topics.** Anything interesting discovered along the way goes into
  section 11, not into these eight weeks.
- **Week 8 is for writing.** A measured project that nobody can read is not
  finished.

## And afterwards

The next three, in order, about two weeks each: **M4** the slab allocator,
which is the obvious gap left by fixed-size values; **M7** zero-copy parse;
then **M5** huge pages. That is a natural second two-month block toward
finishing v1.

---

# 5. Why anyone should care

This section exists because "I built a cache" is not a reason and everybody
knows it. The question is whether the thing being learned is the thing being
hired for. Here is what was found on 2026-11-12, quoted where the text was
retrievable, and flagged where it was not.

## What postings actually say

**QRT**, Core Trading Technology, posted 2026-05-08:

> "Familiarity with scalable I/O models (e.g., epoll, io_uring), lock-free
> structures, and concurrent programming"

That single line covers weeks 1, 6 and 7 of this project.

**Jane Street**, Low-Latency Engineer:

> "Some experience with fast-packet processing in user space and common
> kernel-bypass implementations would be ideal (such as Solarflare
> OpenOnload/TCPDirect/ef_vi, Exablaze, InfiniBand verbs, DPDK)"

and, separately:

> "can you describe modern x86 AMD and Intel cache hierarchies?"

The first is impossible on this hardware and is the reason section 8 has
`BLOCKED` markers in it. The second is answered directly by week 7's `perf
c2c` output.

**Meta**, Host Networking, preferred qualifications:

> "DPDK, eBPF/XDP, AF_XDP, io_uring"

and

> "kernel bypass, zero-copy I/O, and RDMA/RoCEv2"

**Cloudflare**, Spectrum, posted 2026-07-31:

> "sockets, eBPF, network namespaces, netfilter/nftables, tc"

**HRT**, from an interview guide:

> "what does C++'s `memory_order_acquire` actually guarantee on x86 vs ARM?"

That is week 6, exactly.

And the most interesting data point: **HRT and Optiver name no technology at
all.** Optiver's entire ask is "2+ years preferred of C++ experience in
low-latency systems". For firms like those the keyword matters far less than
being able to reason about performance with real numbers — which is what
NUMBERS.md is for.

## Supporting evidence

- **PVLDB 2026 on `io_uring`:** a drop-in swap measured **1.10×** over
  `epoll`, with the conclusion that "Treating io_uring as a drop-in
  replacement in a traditional I/O-worker design is inadequate." The paper
  recommends ring-per-thread, single-issuer. That is this architecture, and
  it is why Design C comes last.
- **ScyllaDB** merged an asymmetric `io_uring` Seastar backend on 2026-07-22.
  Live work, not a settled topic.
- **DPDK is not declining.** DPDK Summit Stockholm ran 2026-05 on DPDK 26.03.
  It is simply unavailable on this machine.

## Where the evidence is weak

**No posting found names "shard-per-core" or "Seastar" as a requirement.**
The choice rests on three things: what postings do name, what is buildable on
this hardware, and the PVLDB finding that `io_uring` only pays off inside
this architecture. It is a judgement. It is not a measured ranking, and this
document does not pretend otherwise.

Not verified: ScyllaDB and ClickHouse posting text, because those pages were
closed or partial; Citadel, IMC and Jump postings, not retrieved at all;
Katran's current production status; Google's `io_uring` stance after 2023.
The Jane Street and HRT quotes come from Built In copies rather than the
official pages, and the interview material is from prep sites rather than
verified candidate reports.

## Five questions to expect, and where each is answered

1. *In your SPSC queue, which memory order is on each load and store, and
   what breaks on ARM if the release store is relaxed?* — week 6
2. *A `GET` lands on core 2 for a key owned by core 5. Walk the path. What
   does the hop cost at p99, and how do real systems avoid it?* — weeks 5
   and 6
3. *Why `DEFER_TASKRUN` with a single issuer? When is `SQPOLL` wrong on a
   six-core box?* — week 7
4. *Your `io_uring` versus `epoll` delta on loopback was X. Why? What changes
   with a real NIC?* — week 7, and the honest-limits paragraph
5. *Describe the Zen 2 cache hierarchy, and show which counters moved when
   you fixed the layout.* — week 7's `perf c2c` before and after

---

# 6. The rules

Ten of them. They exist because every one of them is a mistake that is easy
to make and expensive to discover late.

**Nothing lands without a number.** A performance claim carries the command
that produced it and the date it was measured. A claim without a command is a
guess and gets labelled as one.

**p99.9, never averages.** Record p50, p99, p99.9 and max. An average hides
exactly the event worth fixing. The max is always something stupid; find out
what it was.

**Measure before removing.** A milestone that deletes a layer must first
record what that layer cost. Otherwise "I removed the kernel and it got
faster" is a story, not a result.

**Open-loop load only.** A closed-loop benchmark stops sending while the
server is stalled, so it never records the stall. This is coordinated
omission and it is the single most common way a latency number turns out to
be fiction.

**Noise floor before any claim.** An A/A run — the same binary measured
against itself — comes before the first optimisation and is repeated whenever
the machine changes. A difference smaller than the noise floor is not a
result.

**Three runs minimum.** One run is an anecdote. Record the spread.

**No allocation on the hot path.** Everything pre-allocated at startup.

**No fallback paths.** When an operation fails, let the error propagate. A
silent default hides the bug and makes the incident harder to diagnose later.

**An external oracle decides correctness, not latency.** Real `memcached` and
a real memcached client library are the reference for protocol behaviour, so
a bug cannot be shipped as a feature. They are *not* the latency scoreboard:
`memtier_benchmark` has no UDP request transport, which is why the load
generator is written by hand in week 2.

**A regression is a result you keep.** When a milestone makes things slower,
put the code behind a compile-time flag, record the row with the regression
in it, and write down why. Never silently revert, and never delete the row.

**When a milestone is blocked by hardware, record it and move on.** Mark it
`BLOCKED`, write down what would unblock it, and go to the next one. A
blocked milestone never stops the project.

**One milestone at a time.** Finish it, measure it, record the row, move.

## The eight parts of the system

Every lobster topic belongs to one of these. It is worth holding the
picture in your head while reading them.

```
  ┌─ RX ───────┐ ┌─ PARSE ──┐ ┌─ STORE ────────┐ ┌─ TX ───────┐
  │ epoll /    │ │ memcache │ │ hash table +   │ │ batched    │
  │ io_uring   │→│ text     │→│ slab allocator │→│ replies    │
  └────────────┘ └──────────┘ └────────────────┘ └────────────┘
         ▲              ▲              ▲                ▲
         └──── SHARD MODEL: one core owns one slice ─────┘
                              │
                HARNESS: histogram, perf, load generator
                              │
                BUILD: flags, LTO, PGO, disassembly
```

---

# 7. The topics

The topic list lives in one place:
[`index_cpp.md` in cp-setup](https://github.com/msohail22/cp-setup/blob/main/problem%20list/index_cpp.md).
The lobster topics are numbers 641 to 727 there. They moved on 2026-11-16, so
that there is one list and not two.

---

# 8. The long game

Twenty-four milestones, M0 to M16, spanning roughly 6 to 9 months at eight
hours a week. **None of this is committed.** Section 4 is what is committed.

So why is it here? Because the reasoning in it is correct and expensive to
reproduce. Each milestone records what to build, what "done" means, and — for
the blocked ones — exactly what piece of hardware would unblock it. When the
eight weeks finish and the question becomes "what next", this is the answer,
already thought through.

Read it as a price list and a map, not a commitment.

Two conventions:

- **Numbers are stable.** A milestone keeps its number for the life of the
  project, even while blocked, so NUMBERS.md rows never need renumbering.
  That is why the list jumps from M13b to M16: M14, M15 and M17 to M34 were
  v2 milestones and were removed, and their numbers are not reused.
  Letters — M1a, M2b, M13a — were inserted by the review of 2026-11-12 rather
  than renumbering everything after them.
- **No marker means ready.** `BLOCKED` means the hardware does not exist, and
  the row says what would change that.


Each milestone finishes with a NUMBERS.md row and the topics it ticked.

## v1 — the finishable project

M0 to M13b, plus M16. At the end of v1 there is a working, correct, measured
shard-per-core key-value store, with a NUMBERS.md history explaining every
number. **This is a complete project and a defensible one.**

### Phase 0 — a baseline, and a way to see it

| # | Milestone | Done when |
|---|---|---|
| M0 | Blocking UDP server, `std::unordered_map` | `GET` and `SET` answer correctly against a real memcached client library. One afternoon |
| M0b | `epoll` and `recvmmsg` | many clients, and more than one packet per syscall. This is what makes batching possible later |
| M1 | Correctness oracle | a conformance script runs the same command set against `lobster` and against real `memcached` and diffs the replies |
| M1a | **Hand-written UDP load generator** | open-loop: sends on a fixed schedule, records latency from the *intended* send time. About 300 lines. `memtier_benchmark` cannot do this — it has no UDP request transport, only TCP, TLS and Unix sockets |
| M2 | Honest clock | `clock_gettime(CLOCK_MONOTONIC)` vs `rdtsc` compared, TSC invariance confirmed from `constant_tsc`/`nonstop_tsc`, HdrHistogram wired, p50/p99/p99.9/max printed |
| M2b | **Environment control** | one script that fixes governor, boost, C-states via `/dev/cpu_dma_latency`, SMT, THP and AC power, and a check mode that *refuses to benchmark* when any of them is wrong |
| M2c | **In-process microbenchmark harness** | a second binary that times the store and the parser directly, with the optimiser defeated. Without this, Phase 1 is invisible |
| M2d | **Noise floor (A/A run)** | the same binary measured against itself, three runs, spread recorded. Any later difference smaller than this is not a result |
| M33 | Utilisation curve | latency plotted against offered rate. The knee found and recorded. Little's law confirmed on this machine |

**M2b and M33 were moved here by the review.** The plan previously measured
M1 to M7 before fixing the governor, while also admitting the first p99.9
reading was nonsense until the governor was pinned. M33 is cheap, needs no
new code, and tells you whether any later milestone is worth doing: if the
machine already sits past the knee, no amount of code tuning will help.

### Phase 1 — the data structure

Measured by M2c, the in-process harness. End-to-end numbers cannot see this
work: the loopback kernel path is roughly 10 us and the table is roughly
100 ns.

| # | Milestone | Done when |
|---|---|---|
| M3 | Own hash table | open addressing, 64-byte buckets, SoA layout. Measured against `std::unordered_map` |
| M4 | Slab allocator | variable-length values, no `malloc` on the hot path |
| M5 | Huge pages | `mmap` with `MAP_POPULATE`, 2 MB pages, THP disabled for the baseline so the comparison is honest. TLB misses counted before and after. **NUMA placement is written correctly with `hwloc`/`libnuma` but cannot be measured: 1 node** |
| M6 | Prefetch and batching | several requests in flight so memory trips overlap. Uses `recvmmsg` from M0b. IPC recorded |
| M6b | **Profiling toolchain** | `perf` counters working, flame graphs with frame pointers, `bpftrace` on scheduler and softirq tracepoints, and the Zen 2 top-down equivalent established. From here, an outlier gets a name instead of a shrug |

### Phase 2 — the machine underneath

| # | Milestone | Done when |
|---|---|---|
| M7 | Zero-copy parse | the packet buffer is cast in place with `std::start_lifetime_as`. No allocation on the hot path at all |
| M8 | Boot-time isolation | `isolcpus`, `nohz_full`, `mitigations=off` as a separate experiment. Needs a bootloader edit and a reboot; the kernel already has `CONFIG_NO_HZ_FULL=y` and `CONFIG_CPU_ISOLATION=y`. p99.9 before and after |
| M9 | SMT study | the same run with the sibling thread busy and idle. `/sys/devices/system/cpu/smt/control` is writable at runtime, so no reboot |
| M9b | Container study | the same binary in Docker. p99.9 degradation explained, not just observed |

### Phase 3 — shard per core

Two shards, not four: six cores must also hold the load generator and the
desktop.

| # | Milestone | Done when |
|---|---|---|
| M10 | Shard the table | one core owns one key slice. No locks anywhere in the table. Cache allocation (`cat_l3`, `mba`) applied per shard, after reading from `lstopo` which cores share which 4 MB half of L3 |
| M11 | Flow steering that actually works | the client derives its UDP source port from the key, plus `SO_REUSEPORT`, so a packet lands on the owning core. **Hardware RSS is BLOCKED: `iwlwifi` has one queue, and RSS hashes the 4-tuple, never the key — it could never agree with a key-based shard map on any NIC** |
| M12 | SPSC forwarding queue | hand-written, for keys the port trick cannot place. Padded with `std::hardware_destructive_interference_size`, measured 64 on this CPU. False sharing measured with the padding present and removed. MPSC and MPMC built as the losing comparison |
| M13a | **Shared-table baseline, on purpose** | the table made deliberately shared and protected first by `std::mutex`, then by a spinlock with backoff. This is the thing share-nothing is supposed to beat, and without it the central claim of the project is unmeasured. It is also the only place where CAS, ABA and reclamation genuinely arise |
| M13b | Seqlock on the shared baseline | readers retry instead of locking. Measured against M13a and against M10 |

**M13 was split by the review.** It previously said "measured against the
spinlock of M10", but M10 has no locks, so there was nothing to protect and
nothing to compare. Building the shared version on purpose fixes that and
turns the architecture from an assumption into a measurement.

### Phase 4 — `io_uring`

| # | Milestone | Done when |
|---|---|---|
| M16 | `io_uring`, one ring per core | Design C. One ring per shard, single issuer, `DEFER_TASKRUN`, multishot receive, batched send. A/B against `epoll`. `MSG_ZEROCOPY` measured on large values, where it is expected to win, and on small ones, where it is expected to lose. 4 KB aliasing in the buffer ring checked here |

**M16 was moved into v1 on 2026-11-16**, when v2 was removed. Design C needs
it, so v1 is not complete without it.

**v1 ends here. There is no v2.** Everything that was in v2 — AF_XDP, DPDK,
eBPF steering, SIMD, TCP, the binary protocol, eviction, persistence,
coroutines and fibers — was removed from the plan on 2026-11-16. Their topics
stay in the shared topic list linked from section 7.

---

# 9. What it costs

Two questions anyone starting this should ask and almost nobody does: how long
does it take, and how much code is it?

The answers below are estimates and are labelled as such. The one that
matters is the first line of the first table — 64 hours — because that is the
one that was committed to. Everything else is there so the size of what was
*not* committed to is visible rather than vague.

## Time, if the whole of v1 were built

**Assumption: 8 hours a week**, evenings and weekends, as one person with
C++ experience but no prior networking systems work. Scale everything below
linearly if that is wrong — at 16 hours a week, halve it.

**The committed budget is the two-month plan near the top of this file: 8
weeks, 64 hours, 8 milestones.** The table below is what the whole roadmap
would cost, and it is here to make the size of the remainder explicit, not as
a commitment. Read it as a price list.

| Block | Milestones | Estimate |
|---|---|---|
| Phase 0 | M0, M0b, M1, M1a, M2, M2b, M2c, M2d, M33 | **6 to 9 weeks** |
| Phase 1 | M3, M4, M5, M6, M6b | **7 to 10 weeks** |
| Phase 2 | M7, M8, M9, M9b | **4 to 6 weeks** |
| Phase 3 | M10, M11, M12, M13a, M13b | **7 to 10 weeks** |
| Phase 4 | M16 | **2 to 3 weeks** |
| **v1 total** | **24 milestones** | **26 to 38 weeks — roughly 6 to 9 months** |

Two honest notes on these numbers:

- **Phase 0 is the one people underestimate.** It looks like plumbing and it
  is a third of v1. M1a is a real program, and M2b plus M2d are the
  difference between a project with results and a project with anecdotes.
- **The first milestone over a week with nothing visible is M4**, the slab
  allocator. Real work, and end-to-end p99.9 will not move. M2c exists so
  that it moves *something*.

## Code size

Code lines only, no comments or blanks, `tokei` style. Every figure is an
**estimate**, anchored where possible on the memcached counts measured
2026-11-12 at `2d51e36`.

### Size of the eight weeks

| Component | Week | Estimate |
|---|---|---|
| `epoll` server, `GET`, `SET` | 1 | 350 |
| Build scaffolding: CMake, presets, GTest wiring, justfile | 1 | 300 |
| Open-loop UDP load generator | 2 | 400 |
| Clock, HdrHistogram, stats, A/A run | 3 | 300 |
| `env.sh` with check mode | 3 | 150 |
| **Design A** shared table, striped mutexes, then spinlock | 4 | 350 |
| Hash table, open addressing, SoA | 5 | 500 |
| **Design B** shard-per-core threads, pinning, `SO_REUSEPORT`, key-derived port | 5 | 450 |
| **SPSC ring mesh**, padded, TSan clean | 6 | 400 |
| **Design C** one `io_uring` ring per core | 7 | 450 |
| `perf` harness and the three-way comparison | 7 | 150 |
| Tests across all of it, including TSan tests for the queue | ongoing | 1,000 |
| **Total** | **8 weeks** | **5,200** |

About **5,200 code lines in 64 hours**, or roughly 80 lines an hour including
tests, measurement and debugging. Higher than the earlier 70 because three
thread models share one store, so much of Design B and C is substitution
rather than new code — but the SPSC queue and the `io_uring` path are the
two densest things in the project, and both are in here.

### Size of v1

| Component | Milestone | Estimate | Anchor |
|---|---|---|---|
| UDP server, `epoll`, `recvmmsg` | M0, M0b | 400 | — |
| memcached text protocol, parse and reply | M0, M7 | 600 | `proto_text.c` is 1413 for the full command set; this has two commands |
| Hash table, open addressing, SoA | M3 | 500 | `assoc.c` is **264** for chaining plus incremental resize |
| Slab allocator | M4 | 700 | `slabs.c` is **601** |
| Hugepage and NUMA arena | M5 | 300 | — |
| Prefetch and batching | M6 | 150 | mostly edits to existing code |
| Shard model, thread setup, pinning | M10, M11 | 500 | `thread.c` is **830** |
| SPSC queue, plus the MPSC and MPMC comparisons | M12 | 400 | `rigtorp/SPSCQueue` is about 200 for one queue |
| Shared baseline and seqlock | M13a, M13b | 300 | — |
| `io_uring` ring per core, receive and send | M16 | 500 | — |
| Clock, HdrHistogram wiring, stats | M2 | 300 | — |
| **Server subtotal** | | **4,650** | |
| Load generator, open-loop UDP | M1a | 400 | — |
| In-process microbenchmark harness | M2c | 250 | — |
| Conformance oracle script | M1 | 150 | Python or shell |
| GoogleTest suite | ongoing | 1,200 | about 30% of server code |
| CMake, presets, justfile, `env.sh` | M2b | 400 | — |
| **v1 total** | | **7,000** | |

### What the size numbers say

```
memcached core, measured:       13,047 code lines (12 .c files)
lobster v1, estimated:           7,000
```

About half of memcached, with far fewer commands, but with a load generator
and a microbenchmark harness that memcached's 13k lines do not contain.

Two things worth noticing:

1. **The hash table is 500 lines out of 7,000, about 7%.** The thing the
   project is nominally about is a small part of it. That is the point: the
   learning is concentrated where the code is thin.
2. **Tests and harness are about 2,000 lines, 29% of the total.** That ratio
   is right. Much lower, and the rows in NUMBERS.md are not trustworthy.

Treat the v1 figure as plus or minus 30%. It is anchored on measured
memcached counts for the three components that dominate it.

## Definition of done

Two levels, and the first one is the one that counts right now.

**Done for the two-month plan:** the same key-value store built three ways
— shared table with striped mutexes, shard-per-core with an SPSC ring mesh,
and shard-per-core on `io_uring` — with all three compared on throughput
against core count, p99 and p99.9 at a fixed rate, and `perf stat` counters;
one `perf c2c` before and after showing false sharing removed; and a
TSan-clean SPSC queue with tests. About 26 topics ticked. This is a finished,
defensible project and it is the target.

**Done for v1:** M0 to M13b and M16 complete, every v1 topic either ticked
or marked unmeasurable with the reason. A second two-month block gets most of
the way there, starting with M4.

## Honest limits of the whole roadmap

A laptop, a shared kernel and a WiFi-only machine will not reach the numbers
a tuned server reaches, and loopback is not a network. That is accepted, and
it is why the rules demand relative improvement with an explanation rather
than an absolute number.

"I took the in-process `GET` from 1100 ns to 90 ns, here is the `perf`
counter behind each step, and here is the one case where it got worse and
why" is a better result than a small number nobody can account for.

---

# 10. How it is built

The unglamorous half. Tests, dependencies, the build, the folder layout, and
the one command that runs a benchmark reproducibly.

This section is longer than it feels like it should be, and that is the
lesson. A project like this fails far more often on "I forgot to pin the
governor and now these twelve rows are incomparable" than on anything
algorithmic. The scaffolding *is* the experiment apparatus.

## Testing

GoogleTest is the whole suite, deliberately.

The GoogleTest primer says it "supports *any* kind of tests, not just unit
tests", and names five properties of a good test: independent, repeatable,
organised, portable, fast. A single gtest binary satisfies all five for a
one-person project, and nothing in the GoogleTest documentation restricts it
to unit tests.

- **Tested:** protocol encode and decode round-trips, hash table correctness
  including collisions, the slab allocator free list, and the SPSC queue
  under a producer and a consumer.
- **Tested against an oracle:** M1's conformance script diffs `lobster`
  against real `memcached` on the same command set.
- **Not tested:** latency. A latency number is not pass or fail; it is a
  measurement that depends on the machine. It belongs in NUMBERS.md.

Benchmarks are not tests. They live apart and report numbers.

No test asserting a removed feature is gone. Delete the test instead.

## Build scaffolding

Required by M2, from the review. The current `CMakeLists.txt` is 28 lines and
none of this exists.

- **Split the target.** A `lobster_core` library plus a thin `main.cpp`, so
  tests and benchmarks have something to link against.
- **Fix the smoke test.** `add_test(COMMAND lobster)` runs the binary; once
  `main` is a server it never exits and `ctest` hangs forever.
- **Wire GoogleTest** with `find_package(GTest)` and `gtest_discover_tests`.
  The README promises `ctest` and no gtest target exists yet.
- **Add C to `LANGUAGES`.** HdrHistogram_c is C.
- **`CMakePresets.json`** with release, ASan+UBSan and TSan presets, each in
  its own build directory. TSan is needed by M12 and M13a.
- **Three executables:** the server, the load generator (M1a), and the
  in-process microbenchmark (M2c).
- **Flags:** `-march=native`, `-fno-omit-frame-pointer` for M6b
  flame graphs. Bake the git SHA and the flag set into the binary so a
  NUMBERS.md row can cite exactly what produced it.
- **Pin one compiler.** Both GCC 16.2.1 and Clang 23.1.3 are installed, and a
  number from one is not a number from the other.
- **Dependencies:** HdrHistogram as a pinned submodule in `contrib/` (it is
  not a system package here). liburing is installed and found by
  `pkg-config`, off by default.
- Line 22 of the current file says tests are opt-in while defaulting to `ON`.
  Pick one.
## Dependencies

The language is **C++**, pinned. Standard is **C++23**: everything
load-bearing — `std::start_lifetime_as`, `std::expected`, `std::atomic_ref`,
`std::mdspan`, `std::hardware_destructive_interference_size` — is in 23, and
C++26 is still moving. Compiler is **Clang**, because `llvm-mca` comes from
the same toolchain.

The hot path is written as "C with templates": no allocation, no virtual
calls, no exceptions, no standard containers. The comfortable C++ stays in
startup, config, tests and the load generator. `-fno-exceptions` is applied
to the core library only.

Checked on this machine 2026-11-12 with `pacman -Q` and `pkg-config
--modversion`.

### Already installed

| What | Version | Used by |
|---|---|---|
| `clang` / `llvm` | 23.1.3 | the whole project; `llvm-mca` for reading the probe loop |
| `gcc` | 16.2.1 | second opinion on codegen only, never for a NUMBERS.md row |
| `cmake` | 4.4.4 | build |
| `ninja` | 1.13.2 | build |
| `just` | 1.59.0 | the `just bench <milestone>` entry point |
| `gtest` | 1.18.0 | the whole test suite |
| `liburing` | 2.15 | M16 |
| `libbpf` | 1.7.0 | not used: its only user, M19, was removed with v2 |
| `xxhash` | 0.8.4 | M3 |
| `numactl` (libnuma) | 2.0.19 | M5. No `.pc` file, so link by name |
| `hwloc` | 2.15.0 | M2b, M5, M10 — reading the real topology before pinning |

### Must be installed before M2

| What | Why | Note |
|---|---|---|
| `perf` | M6b, and every counter claim in the plan | not installed |
| `bpftrace` | M6b — naming the outlier instead of shrugging | not installed |
| `ethtool` | M11 — queues, offloads, timestamping capability | not installed. Needed to verify several hardware claims in this file |
| `cpupower` | M2b governor and boost control | not installed |
| `memcached` | M1, the correctness oracle | not installed |
| a memcached client library | M1, to drive the oracle diff | `pymemcache` via `uv` is enough |

### Vendored in `contrib/` as pinned submodules

| What | Why not a package |
|---|---|
| `HdrHistogram_c` | not an Arch package, and `pkg-config --modversion hdr_histogram` finds nothing. It is C, so `LANGUAGES CXX C` is required in CMakeLists.txt |

### Optional, found by `pkg-config`, off by default

Guarded by a CMake option so a plain build never needs it: `liburing` (M16).

### Explicitly not a dependency

| What | Why |
|---|---|
| **DPDK** | out of scope, removed with v2 |
| `memtier_benchmark` | cannot generate UDP requests. M1a replaces it |
| `std::simd` | SIMD is out of scope, removed with v2. Also C++26, and absent from this libstdc++ (verified: `__cpp_lib_simd` undefined) |
| Google Benchmark | the `benchmark` package is not installed, and M2c needs latency distributions rather than throughput means. The harness is written by hand |
| jemalloc / tcmalloc | studied as a topic, but the hot path allocates nothing, so neither is linked |
| Boost | nothing in the plan needs it |
| any async framework | Asio, libevent, and similar. They optimise throughput and ergonomics; this project optimises tail latency |

### Install line

```sh
sudo pacman -S perf bpftrace ethtool cpupower memcached
```

## NUMBERS.md

Created at M1a. Append-only, never rewritten:

```
date | milestone | sha | machine | transport | shards | rate | value_sz | keys
     | clock | runs | p50 | p99 | p99.9 | max | ops/s | spread | command
```

`machine` points at a row in MACHINE.md, which records CPU, kernel, kernel
command line, governor, boost, SMT, THP, mitigations, compiler and flags.
Without it, two rows are not comparable.

A row is never edited, including a row that got worse, because the history of
the numbers is the point of the project.

## One entry point

```
just bench <milestone>
```

It checks the environment and refuses if it is wrong, pins the server and the
load generator to different cores, runs three times, appends the NUMBERS.md
row with the git SHA, and restores the environment. Otherwise it is twenty
`sudo` commands that get forgotten between sessions, and the rows stop being
comparable.

## Folder layout

Flat until a milestone forces a split. The target shape:

```
lobster/
  CMakeLists.txt  CMakePresets.json  justfile
  README.md  PLAN.md  NUMBERS.md  MACHINE.md
  assets/            logo and social preview
  src/
    main.cpp
    Net/             sockets, poll loops, io_uring
    Protocol/        memcached text protocol, framing
    Store/           the hash table and the slab allocator
    Concurrency/     SPSC queue, seqlock
    Memory/          hugepages, NUMA placement, arenas
    Timing/          clocks, rdtsc, the histogram
    Common/          helpers used everywhere
  tests/
    gtest_*.cpp      the suite
    conformance/     the memcached oracle diff (M1)
  bench/
    loadgen/         the open-loop UDP generator (M1a)
    micro/           the in-process harness (M2c)
  scripts/
    env.sh           governor, C-states, SMT, THP; with a check mode
  contrib/           third-party, as submodules
```

Directories are created when the first file needs them. No empty folders with
`.gitkeep`.

## Reference material

| What | Read it for |
|---|---|
| `memcached/memcached` | the design, from the original. Flat layout, no `src/`. Read `assoc.c` (264 code lines: the whole hash table, including incremental resize), `slabs.c` (601), `items.c` (1404) and `thread.c` (830) — 3099 lines in total. Skip `proxy_*.c` and `proto_proxy.c` (10886 lines, a separate Lua-scriptable product). Measured 2026-11-12 at `2d51e36` with `tokei -o json --files` |
| `scylladb/seastar`, design docs before code | shard per core, share nothing, done properly in production |
| `rigtorp/SPSCQueue` | about 200 lines that teach false sharing properly |
| `rigtorp/awesome-lockfree` | the reading list for Phase 3 |
| `axboe/liburing`, the `examples/` directory | `io_uring` from its author |
| `HdrHistogram/HdrHistogram_c` | recording latency without lying about the tail |
| Gil Tene, "How NOT to Measure Latency" | coordinated omission. Watch before writing M1a |
| Agner Fog's optimisation manuals, AMD's Zen 2 optimisation guide | the microarchitecture reference for Phase 2 |
| `bpftrace`, `bcc` | finding the p99.9 cause instead of guessing it |

Skip tutorials on `select()`. Read `redis/redis` `ae_epoll.c` instead; it is
shorter than most blog posts about it.

---

# 11. Open questions

Decisions deliberately not made yet, because the information needed to make
them does not exist. They live here rather than in the body so that reading
the plan does not feel like reading an argument with itself.

Anything interesting discovered during the eight weeks gets added here, and
nowhere else.


- Does M11's "client derives its port from the key" distort the benchmark by
  making the client do work a real client would not? Probably yes. Record it.
- Hash function: a hand-written one, or `xxhash`? Leaning `xxhash` at M3, so
  the milestone is about layout rather than the hash, then measuring whether
  the hash shows up at all.
- Fixed-size or resizable table? Leaning fixed at M3, because resize is the
  cold path and it complicates reclamation.
- How many keys fit? 3 GB available, so the "10M entries" figure needs
  recomputing against the real bucket size before M3.
