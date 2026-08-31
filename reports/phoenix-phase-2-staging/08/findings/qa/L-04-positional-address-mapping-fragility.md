# L-04 — Off-chain address patch maps new strategies to tokens by positional CREATE index; a future Phase-B reorder silently mis-writes mainnet-addresses.ts

- **Severity:** QA
- **Status:** draft (new)
- **Entry point:** `migrate:ss-execute-mainnet`
- **Category:** drift
- **Root cause class:** PositionalAddressMappingFragility
- **Location:** `scripts/patch-mainnet-addresses-stable-staker.js` — `resolveAddresses`
- **Fork-verified:** no (static analysis — off-chain registry, no on-chain effect)
- **Fingerprint:** `3ff5624889f548e6c6f9054a40c4ce329dc1fff22b22f4e5e6e8436997a52edc`

## Description

The post-broadcast JS step `patch-mainnet-addresses-stable-staker.js` overwrites
`YieldStrategy{Dola,USDC,USDe}` in `server/deployments/mainnet-addresses.ts` from the
broadcast log. It associates each newly-deployed `ERC4626YieldStrategy` with its token by
**positional index** — the Nth `ERC4626YieldStrategy` CREATE in the broadcast is assumed to
be the Nth token in the script's fixed Phase B order (DOLA → USDC → USDe). The mapping is
purely ordinal; it does not bind a deployed strategy address to the token it actually serves.

If a future revision reorders the Phase B deploy loop, inserts a strategy, or otherwise
changes CREATE order without updating the JS in lockstep, the patch silently writes the
**wrong** strategy address under each token key, with no error.

## Impact

QA. Off-chain registry only — `mainnet-addresses.ts` is a deployment bookkeeping file; the
mis-write has **no on-chain effect** and the on-chain cutover itself remains correct. The
consequence is downstream off-chain confusion (server/tooling reading a strategy address
mapped to the wrong token) until corrected.

## Fork-verification note

Static. Established by reading the JS resolver, which keys off CREATE ordinal rather than the
deployed contract's `underlyingToken()`. No fork run is relevant since the file is off-chain.

## Recommendation

Bind each deployed strategy to its token by reading the deployed contract's
`underlyingToken()` (or matching against the constructor `token` argument captured in the
broadcast log) instead of relying on positional CREATE order, so a Phase-B reorder cannot
silently mis-map addresses.
