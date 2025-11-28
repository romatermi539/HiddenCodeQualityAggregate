# Hidden Code Quality — Aggregate-Only Scoring (Zama FHEVM)

**One‑line**: Encrypted code metrics in, **public aggregate** out. Individual submissions stay private; only the global sum (and off‑chain average) are revealed.

## Why

Security reviews often want a *team‑level* health signal without exposing per‑author details. This dApp lets contributors submit **encrypted** metrics (coverage/style/complexity/bugs). The contract computes a private score per submission and **aggregates** them. Only the **aggregate sum** is made publicly decryptable; no personal breakdown is ever revealed onchain.

---

## Main Features

* **Private inputs**: Users encrypt 4 metrics locally via Relayer SDK 0.2.0, then call `submitMetrics(...)` with attested handles.
* **Encrypted policy** (owner): Upload threshold policy using `setPolicyEncrypted(...)`; optionally mark policy as public for auditability.
* **Aggregate‑only output**: The contract tracks `sumScore` and `submissions`. Owner (or anyone, per your contract) can `publishSum()` → the sum handle becomes globally decryptable; the UI computes **average = sum / submissions** off‑chain.
* **No plain dev paths**: Frontend ships **without** any "Set Plain (dev)" flow.
* **Clean UX**: Minimal editorial design, clear logs, Sepolia autoswitch, defensive input validation.

> **Scoring (example implementation)**: Each satisfied check (cov≥min, style≥min, compl≤max, bugs≤max) adds **25 points** → per‑submission score ∈ {0,25,50,75,100}. (Adjust if your deployed contract differs.)

---

## Repository Layout

```
frontend/
  public/
    index.html   # This app (vanilla ESM). No build step required.
```

---

## Prerequisites

* Node 18+ (for running a static server, optional)
* Browser wallet (MetaMask)
* Sepolia account with gas

---

## Quick Start (Serve Static)

You can open the HTML directly, but for WASM workers and EIP‑712 flows a local server is recommended.

```bash
# from repo root
# 1) serve the public folder (pick one)
# a) using npx http-server
npx http-server frontend/public -p 5173 --cors
# b) using python
python3 -m http.server --directory frontend/public 5173

# 2) open
http://localhost:5173
```

The page will:

1. Connect wallet → autoswitch to Sepolia.
2. Initialize Relayer SDK (0.2.0) against the hosted testnet relayer.
3. Bind to contract `0x4A8b95…112f` via Ethers v6.

---

## How to Use (UI)

**As a contributor**

1. Open the app, click **Connect Wallet**.
2. In **Submit Encrypted Metrics**, enter integers 0..100 for: Coverage, Style, Complexity, Bugs.
3. Click **Submit Metrics (Encrypted)**. The UI creates an encrypted input buffer, gets handles + proof, and sends the tx.
4. Check the status panel and TX hash.

**As owner (policy management)**

1. In **Policy (Thresholds)**, fill `tCovMin`, `tStyleMin`, `tComplMax`, `tBugsMax` (0..100).
2. Click **Set Encrypted** → uploads thresholds as ciphertexts.
3. (Optional) **Make Policy Public** for transparent audits.

**Publishing & reading aggregate**

1. Click **Publish Sum (public)** → the contract marks `sumScore` for public decryption.
2. Click **Decrypt Sum** → frontend calls `publicDecrypt` via Relayer → shows **Avg** = `sum / submissions`.

---

## Configuration

The defaults are embedded in `index.html`:

* **Contract**: `0x4A8b95270369De027a34E02b49FFe1D49d97112f`
* **Network**: Sepolia (chain id `0xaa36a7`)
* **Relayer URL**: `https://relayer.testnet.zama.cloud`

If you need to change them, edit the constants at the top of the script block.

---


## Roadmap / Ideas

* Export CSV of decrypted aggregate history.
* Multi‑policy versions + time windows.
* Per‑team namespaces with the same aggregate‑only guarantee.

---

## License

MIT (project code). Zama SDKs/libraries are under their respective licenses.
