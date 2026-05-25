#!/bin/bash
# SessionStart hook: provision the deterministic audit toolchain.
# Idempotent and resilient — each install is guarded by `command -v`, so this is a
# fast no-op when tools already exist (local machine), and an individual tool
# failing NEVER blocks the session (no `set -e`).
set -uo pipefail

log()  { echo "[audit-setup] $*"; }
have() { command -v "$1" >/dev/null 2>&1; }

export PATH="$HOME/.foundry/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# --- source submodules (non-recursive; read-only audit references) ---
if [ -f .gitmodules ]; then
  log "initializing submodules"
  git submodule update --init >/dev/null 2>&1 || log "WARN: submodule init failed"
fi

# --- Foundry (forge, cast, anvil) ---
if ! have forge; then
  log "installing foundry"
  curl -fsSL --connect-timeout 10 --max-time 300 https://foundry.paradigm.xyz | bash >/dev/null 2>&1 \
    && "$HOME/.foundry/bin/foundryup" >/dev/null 2>&1 || log "WARN: foundry install failed"
fi

# --- pipx-managed Python tools: slither, halmos, semgrep ---
if ! have pipx; then
  python3 -m pip install --user pipx >/dev/null 2>&1 && python3 -m pipx ensurepath >/dev/null 2>&1 || true
fi
for tool in "slither:slither-analyzer" "halmos:halmos" "semgrep:semgrep"; do
  bin="${tool%%:*}"; pkg="${tool##*:}"
  if ! have "$bin"; then
    log "installing $bin"
    if have pipx; then pipx install "$pkg" >/dev/null 2>&1 || log "WARN: $bin install failed"
    else python3 -m pip install --user "$pkg" >/dev/null 2>&1 || log "WARN: $bin install failed"; fi
  fi
done
# solc-select helps Slither match project pragmas
have solc-select || python3 -m pip install --user solc-select >/dev/null 2>&1 || true

# --- Aderyn (Cyfrin, Rust static analyzer) ---
if ! have aderyn; then
  log "installing aderyn"
  { curl -fsSL --connect-timeout 10 --max-time 300 https://raw.githubusercontent.com/Cyfrin/aderyn/dev/cyfrinup/install | bash >/dev/null 2>&1 \
      && "$HOME/.cyfrin/bin/cyfrinup" >/dev/null 2>&1; } \
    || { have cargo && cargo install aderyn >/dev/null 2>&1; } \
    || log "WARN: aderyn install failed (try: cargo install aderyn)"
fi

# --- Medusa (Trail of Bits stateful fuzzer) ---
if ! have medusa && have go; then
  log "installing medusa"
  go install github.com/crytic/medusa@latest >/dev/null 2>&1 || log "WARN: medusa install failed"
fi

# --- 4naly3er (C4 automated QA/gas report) cloned under tools/ ---
if [ ! -d tools/4naly3er ]; then
  log "cloning 4naly3er"
  git clone --depth 1 https://github.com/Picodes/4naly3er tools/4naly3er >/dev/null 2>&1 \
    && (cd tools/4naly3er && yarn install >/dev/null 2>&1) || log "WARN: 4naly3er setup failed (needs node/yarn)"
fi

# --- report a concise readiness line ---
ready=""; missing=""
for t in forge slither halmos aderyn medusa semgrep; do
  if have "$t"; then ready="$ready $t"; else missing="$missing $t"; fi
done
log "ready:${ready:- none}"
[ -n "$missing" ] && log "missing:$missing (pipeline degrades gracefully; rerun this hook to retry)"
exit 0
