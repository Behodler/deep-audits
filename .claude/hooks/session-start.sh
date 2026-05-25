#!/bin/bash
# SessionStart hook: provision the deterministic audit toolchain.
# Idempotent and resilient — each install is guarded by `command -v`, so this is a
# fast no-op when tools already exist (local machine), and an individual tool
# failing NEVER blocks the session (no `set -e`).
set -uo pipefail

log()  { echo "[audit-setup] $*"; }
have() { command -v "$1" >/dev/null 2>&1; }

export PATH="$HOME/.foundry/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
mkdir -p "$HOME/.local/bin"

# Print the browser_download_url from a repo's latest GitHub release matching $2 (a
# grep -E pattern). Lets us pull prebuilt binaries instead of needing a compiler.
gh_latest_asset() { # $1=owner/repo  $2=asset-name pattern
  curl -fsSL --connect-timeout 10 --max-time 30 "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | grep -oE '"browser_download_url": *"[^"]+"' | sed -E 's/.*"(https[^"]+)".*/\1/' \
    | grep -E "$2" | head -1
}

# Download a release tarball ($2), extract it, and install the binary named $3 into
# ~/.local/bin. Handles both .tar.gz and .tar.xz. Returns non-zero on any failure.
install_release_bin() { # $1=download-url  $2=archive-filename  $3=binary-name
  local url="$1" arc="$2" name="$3" tmp bin rc
  tmp="$(mktemp -d)" || return 1
  curl -fsSL --connect-timeout 10 --max-time 300 -o "$tmp/$arc" "$url" >/dev/null 2>&1 \
    && tar xf "$tmp/$arc" -C "$tmp" >/dev/null 2>&1
  rc=$?
  if [ $rc -eq 0 ]; then
    bin="$(find "$tmp" -type f -name "$name" | head -1)"
    if [ -n "$bin" ]; then install -m755 "$bin" "$HOME/.local/bin/$name"; rc=$?; else rc=1; fi
  fi
  rm -rf "$tmp"; return $rc
}

# Map `uname -m` to the arch token a project uses in its release asset names.
arch_token() { # $1=style: "rust" (x86_64/aarch64) | "go" (x64/arm64)
  case "$(uname -m)" in
    x86_64|amd64)  [ "$1" = go ] && echo x64    || echo x86_64 ;;
    aarch64|arm64) [ "$1" = go ] && echo arm64  || echo aarch64 ;;
    *) echo "" ;;
  esac
}

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

# --- Python tools: slither, halmos, semgrep ---
# pip_user installs into ~/.local; the --break-system-packages retry handles
# PEP 668 "externally-managed" distros (Debian/Ubuntu) where plain --user is refused.
pip_user() { # $@=packages
  python3 -m pip install --user "$@" >/dev/null 2>&1 \
    || python3 -m pip install --user --break-system-packages "$@" >/dev/null 2>&1
}
if ! have pipx; then pip_user pipx && python3 -m pipx ensurepath >/dev/null 2>&1 || true; fi
for tool in "slither:slither-analyzer" "halmos:halmos" "semgrep:semgrep"; do
  bin="${tool%%:*}"; pkg="${tool##*:}"
  if ! have "$bin"; then
    log "installing $bin"
    if have pipx; then pipx install "$pkg" >/dev/null 2>&1 || pip_user "$pkg" || log "WARN: $bin install failed"
    else pip_user "$pkg" || log "WARN: $bin install failed"; fi
  fi
done
# solc-select helps Slither match project pragmas
have solc-select || pip_user solc-select || true

# --- Aderyn (Cyfrin, Rust static analyzer) — prefer prebuilt release binary ---
if ! have aderyn; then
  log "installing aderyn"
  a="$(arch_token rust)"; url="${a:+$(gh_latest_asset Cyfrin/aderyn "aderyn-${a}-unknown-linux-gnu\.tar\.xz")}"
  if [ -n "$url" ] && install_release_bin "$url" aderyn.tar.xz aderyn; then :
  elif have cargo && cargo install aderyn >/dev/null 2>&1; then :
  else log "WARN: aderyn install failed (no prebuilt asset for $(uname -m); try: cargo install aderyn)"; fi
fi

# --- Medusa (Trail of Bits stateful fuzzer) — prefer prebuilt release binary ---
if ! have medusa; then
  log "installing medusa"
  a="$(arch_token go)"; url="${a:+$(gh_latest_asset crytic/medusa "medusa-linux-${a}\.tar\.gz")}"
  if [ -n "$url" ] && install_release_bin "$url" medusa.tar.gz medusa; then :
  elif have go && go install github.com/crytic/medusa@latest >/dev/null 2>&1; then :
  else log "WARN: medusa install failed (no prebuilt asset for $(uname -m) and no go)"; fi
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
