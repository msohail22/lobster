# Project Guide: Market Data Feed Handler + Order Book Builder

## 1. What even is this, in plain words?

Every stock exchange constantly broadcasts a stream of tiny messages: "someone placed a buy order," "someone cancelled an order," "two orders just matched and traded," etc. This stream is called a **market data feed**.

A **feed handler** is a program that:
1. Catches every single one of those messages, in order, without ever missing one.
2. Uses them to keep an up-to-date picture of the order book (who wants to buy/sell what, at what price).
3. Does this continuously, fast enough that it never falls behind the real exchange.

That's it. It's not "just a parser." A parser reads data once and stops. A feed handler runs forever, has to keep up with a live firehose, and has to never get the book state wrong — because every other system downstream (the trading strategy, the matching engine, the risk system) depends on it being correct and current.

**Is "processing data at very high speed" the goal?**
Sort of, but reframe it: the real goal is "never fall behind." Speed is the *means*, not the *point*. A feed handler that's blazing fast on average but occasionally stalls for 50ms is worse than one that's consistently just-fast-enough with no stalls. That's why later in this guide you'll measure "worst case" latency (p99, p99.9), not just average speed.

## 2. Why this project (not another order book / matching engine)

Matching engines (the thing that pairs buyers and sellers) are the most cloned portfolio project in this space — dozens of nearly identical repos exist. A feed handler is:
- Less commonly built well, so it stands out more.
- The literal first component in any real trading system's pipeline — you can't have a matching engine or a strategy without one.
- A direct extension of skills you're already building in your low-level-lab repo: binary parsing, memory layout, concurrency, networking.
- A common topic in actual quant dev / HFT infra interviews.

## 3. Where to get real data

Nasdaq publishes a real binary protocol called **TotalView-ITCH 5.0**, and — usefully — free historical sample files.

- **Sample data file (one trading day, real Nasdaq order flow):**
  `ftp://emi.nasdaq.com/ITCH/08302019.NASDAQ_ITCH50.gz`
  (This is a `.gz` compressed binary file. Unzip it and you have a raw byte stream of real exchange messages to parse.)

- **Official protocol specification (tells you exactly how to read the bytes):**
  Nasdaq TotalView-ITCH 5.0 spec PDF — search "Nasdaq TotalView-ITCH 5.0 Specification PDF," published by Nasdaq Trader (nasdaqtrader.com). This document defines every message type (add order, cancel, execute, etc.) and the exact byte layout of each one. This is your source of truth — don't guess the format, read it from here.

## 4. What the protocol actually looks like (so it's not a mystery)

ITCH is a sequence of messages, one after another, each starting with a single letter telling you what kind of message it is. A few of the important ones:
- `S` — System event (start of day, start of trading, end of day, etc.)
- `R` — Stock directory (tells you what symbols exist)
- `A` — Add order (someone placed a new order)
- `E` — Order executed (an order got (partially) filled)
- `X` — Order cancel
- `D` — Order delete
- `U` — Order replace (modify)
- `P` — Trade message

Each message is a fixed number of bytes with fields like order ID, price, quantity, symbol, packed in "big-endian" binary form (not text). Your parser's job is to read the message-type letter, then read the right number of bytes for that message type, and turn it into a usable struct in your program.

## 5. The build plan, explained simply

### Phase 1 — Just get it correct (no speed concerns yet)
Write a single-threaded C++ program that:
- Opens the unzipped ITCH file.
- Reads one message at a time.
- Parses it into a struct based on its type.
- Updates a simple order book (can be a `std::map` — slow but easy to get right).

Goal: correctness. Don't optimize anything yet. This becomes your "known good" reference to check later versions against.

### Phase 2 — Make the book data structure good
Replace the slow `std::map`/`std::list` book with something built for speed: e.g., a flat array indexed by price level, with orders in a simple linked list at each level. This gives you O(1) (constant time, not "search through everything") add/cancel operations instead of the tree-based O(log n) you get from `std::map`.

### Phase 3 — Split into two threads
Right now, one thread does everything: read message → parse → update book. Split it:
- **Thread A ("reader")**: just reads raw bytes as fast as possible and hands them off.
- **Thread B ("processor")**: takes what Thread A handed off and updates the book.

They communicate through a **ring buffer** — a fixed-size circular queue in memory, built so the two threads don't need to lock/block each other (this is what people mean by "lock-free"). This matters because if your reader ever has to wait on your processor (or vice versa), you can fall behind the live feed.

### Phase 4 — Measure it properly
Most portfolio repos just say "X million messages/sec!" with no real evidence. Do it properly:
- Time every message from "read" to "book updated."
- Build a **histogram** of these times (an HDR Histogram library is the standard tool for this — look up "HdrHistogram C++").
- Report p50 (typical case), p99, and p99.9 (worst-case-ish), not just an average.
- Compare these numbers against your slow Phase-1 version, so you have real "before vs. after" evidence.

### Phase 5 — Make it feel live
Write a small second program that reads the same sample file and re-sends it over the network (UDP) at (roughly) the speed it would have arrived in real life. Point your feed handler at this instead of reading straight from the file. Now you have something that behaves like a real live system, not just a batch script.

### Phase 6 (optional, later) — Connect it to ClickHouse
Since you're already doing ClickHouse open source work, write your normalized book snapshots or trade events into ClickHouse. Now your two projects form one story instead of two disconnected repos — a systems-level feed handler feeding a real analytical database.

## 6. What to actually write in your README (this is what gets read)

- 2–3 sentences: what a feed handler is and why it exists (use section 1 above, in your own words).
- An architecture diagram: file/network → reader thread → ring buffer → processor thread → book state → (optional) ClickHouse.
- Your before/after benchmark numbers with the histogram, not just one big number.
- 2–3 design decisions that mattered and why (e.g., "why I used a ring buffer instead of a mutex-protected queue," "why flat arrays instead of a map for price levels").
- A short "what I'd do differently at 10x the scale" section. This single section is the biggest signal of engineering maturity — almost nobody includes it, and it shows you understand tradeoffs, not just that you copied a pattern.

## 7. References to actually learn from (not to copy)

- **Protocol spec:** Nasdaq TotalView-ITCH 5.0 Specification (PDF), published on nasdaqtrader.com — your ground truth for message formats.
- **Sample data:** `ftp://emi.nasdaq.com/ITCH/08302019.NASDAQ_ITCH50.gz`
- **Existing ITCH parsers to study the approach of (don't copy-paste, but reading a working parser's structure helps a lot when you're stuck):** search GitHub for "Nasdaq ITCH 5.0 parser C++" — there are several public parsers you can read for reference once you've attempted your own first.
- **Lock-free ring buffers:** search "SPSC lock-free ring buffer C++" for reference implementations and explanations of the technique (cache-line padding, memory ordering).
- **Latency histograms:** look up "HdrHistogram" — it's the standard library for measuring latency distributions properly instead of averages.
- **General reading:** the book *"Building Low Latency Applications with C++"* covers a lot of this exact territory (feed handlers, ring buffers, order books) if you want a structured walkthrough rather than piecing it together from repos.

## 8. Realistic scope

4–6 weeks of evenings/weekends if you stop being a perfectionist after Phase 5. Phase 6 is a bonus, not a requirement. Don't let this balloon into a "trading platform" — the whole point is a focused, correct, well-measured, well-explained system.
