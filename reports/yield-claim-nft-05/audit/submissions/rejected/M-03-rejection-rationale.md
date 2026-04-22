**Rejection rationale (lead auditor + severity-auditor agreement, 2026-04-22):**

Internally contradictory and describes intentional design as a vulnerability.

(1) The PoC table demonstrates the effective ratio drops from 3000 → 2592 bps over time, meaning the recipient under-claims relative to current backing. The Impact section claims the opposite direction ("value leak from NFT holders to the hook's recipient", "drain sUSDS whose USDS-equivalent value is larger than the ratio%"). The narrative contradicts the arithmetic.

(2) The user deposits USDS — the wrap to sUSDS is an internal implementation detail. The user is promised ratio% of the USDS they parted with, and that is what mintDebt records. DSR yield accruing on the dispatcher's sUSDS is protocol-retained surplus that strengthens the phUSD backing / safety buffer for NFT holders. Freezing mintDebt in USDS terms is a conservative cap on phUSD issuance, not a leak.

(3) The proposed Option A fix would inflate phUSD against unchanged user deposits, drain the sUSDS/phUSD pool faster than new deposits replenish it, and weaken the phUSD peg — a regression, not a mitigation. No documented spec or invariant requires mintDebt to track sUSDS yield.
