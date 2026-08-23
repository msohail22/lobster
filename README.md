<div align="center">
  <img src="assets/lobster.png" width="160" alt="lobster logo" />
  <h1>lobster</h1>
  <p><b>A high-performance C++ feed handler that turns a raw NASDAQ ITCH 5.0 data stream into a live order book.</b></p>
</div>

---

## Overview

**lobster** is a low-latency C++ market data feed handler and order book builder. It ingests raw binary TotalView-ITCH 5.0 messages from NASDAQ, parses them, and maintains an up-to-date limit order book state in real time.

### Architecture Highlights
- **Binary ITCH 5.0 Parser**: Fast fixed-width binary parsing for system events, order additions, executions, cancels, and replaces.
- **SPSC Ring Buffer**: Lock-free queue separating raw network/file ingestion from book state processing.
- **Fast Order Book Layout**: Constant-time O(1) order additions and cancellations across price levels.
- **Latency Profiling**: Microsecond-accurate distribution tracking (p50, p99, p99.9) using HDR histograms.

used the data in this link here: https://emi.nasdaq.com/ITCH/Nasdaq%20ITCH/ and the name of the file is 08302019.NASDAQ_ITCH50.gz
