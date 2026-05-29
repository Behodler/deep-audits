---
name: owner-driven-attacks-invalid
description: Owner/admin-driven attack paths are invalid findings — do not report them as High/Medium
metadata:
  type: feedback
---

Owner-driven attacks are **invalid** findings. Any vulnerability whose exploit path requires the owner/admin (or other privileged role) to misconfigure, act maliciously, or set a state the protocol gives them authority to set is out of scope — this is the C4 "reckless admin mistakes" known-invalid class.

**Why:** The protocol trusts privileged roles by design; an attack that only works because a trusted role did something it shouldn't is not a protocol flaw the audit should surface as H/M.

**How to apply:** When adjudicating a finding, strip every exploit sub-vector that depends on an owner/admin action or configuration (e.g. "owner pins a zero-price dispatcher", "owner over-funds a pot relative to cost"). Only what remains **permissionless** (exploitable by an unprivileged attacker against normal/intended operation) can be a valid H/M. A "supported state" argument does not rescue an owner-driven vector — if reaching the state requires an owner choice, it's still owner-driven. Genuinely permissionless dynamics (e.g. MEV/front-running a legitimately-funded incentive) remain valid. See [[nft-staking-batchminter-nudge]].
