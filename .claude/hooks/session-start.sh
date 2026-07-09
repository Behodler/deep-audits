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

# Same as gh_latest_asset but for a pinned release tag ($2), enabling reproducible installs.
gh_tagged_asset() { # $1=owner/repo  $2=tag  $3=asset-name pattern
  curl -fsSL --connect-timeout 10 --max-time 30 "https://api.github.com/repos/$1/releases/tags/$2" 2>/dev/null \
    | grep -oE '"browser_download_url": *"[^"]+"' | sed -E 's/.*"(https[^"]+)".*/\1/' \
    | grep -E "$3" | head -1
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

# --- toolchain version pins (reproducibility) ---
# Defaults are the versions this pipeline was validated against (see docs/tooling-rigor-*).
# An audit toolchain that silently tracks `latest` is not reproducible: a tool regression
# quietly changes findings run-to-run. Override any pin via env to bump or roll back
# (e.g. AUDIT_ADERYN_VERSION=0.7.0), or set AUDIT_TOOLCHAIN_LATEST=1 to ignore all pins and
# take each tool's latest release. Pinned installs FALL BACK to latest on failure, so a bad
# pin never leaves the session with a missing tool (fail-safe > exact-pin).
: "${AUDIT_FOUNDRY_VERSION:=}"          # empty => foundryup default (latest stable)
: "${AUDIT_SLITHER_VERSION:=0.11.3}"
: "${AUDIT_HALMOS_VERSION:=0.3.3}"
: "${AUDIT_SEMGREP_VERSION:=}"          # empty => latest (semgrep pins are heavy; opt-in)
: "${AUDIT_ADERYN_VERSION:=0.6.8}"
: "${AUDIT_MEDUSA_VERSION:=1.5.1}"
if [ "${AUDIT_TOOLCHAIN_LATEST:-0}" = 1 ]; then
  AUDIT_FOUNDRY_VERSION=""; AUDIT_SLITHER_VERSION=""; AUDIT_HALMOS_VERSION=""
  AUDIT_SEMGREP_VERSION=""; AUDIT_ADERYN_VERSION=""; AUDIT_MEDUSA_VERSION=""
  log "AUDIT_TOOLCHAIN_LATEST=1 — ignoring version pins, installing latest"
fi

# --- source submodules (recursive; we audit the living latest of each repo + its nested deps) ---
if [ -f .gitmodules ]; then
  log "initializing submodules (recursive)"
  git submodule update --init --recursive >/dev/null 2>&1 || log "WARN: submodule init failed"
fi

# --- Foundry (forge, cast, anvil) ---
if ! have forge; then
  log "installing foundry${AUDIT_FOUNDRY_VERSION:+ (pinned $AUDIT_FOUNDRY_VERSION)}"
  curl -fsSL --connect-timeout 10 --max-time 300 https://foundry.paradigm.xyz | bash >/dev/null 2>&1
  if [ -n "$AUDIT_FOUNDRY_VERSION" ]; then
    "$HOME/.foundry/bin/foundryup" --install "$AUDIT_FOUNDRY_VERSION" >/dev/null 2>&1 \
      || "$HOME/.foundry/bin/foundryup" >/dev/null 2>&1 || log "WARN: foundry install failed"
  else
    "$HOME/.foundry/bin/foundryup" >/dev/null 2>&1 || log "WARN: foundry install failed"
  fi
fi

# --- Python tools: slither, halmos, semgrep ---
# pip_user installs into ~/.local; the --break-system-packages retry handles
# PEP 668 "externally-managed" distros (Debian/Ubuntu) where plain --user is refused.
pip_user() { # $@=packages
  python3 -m pip install --user "$@" >/dev/null 2>&1 \
    || python3 -m pip install --user --break-system-packages "$@" >/dev/null 2>&1
}
if ! have pipx; then pip_user pipx && python3 -m pipx ensurepath >/dev/null 2>&1 || true; fi
# fields: bin:pip-package:pinned-version (version may be empty => latest)
for tool in "slither:slither-analyzer:$AUDIT_SLITHER_VERSION" "halmos:halmos:$AUDIT_HALMOS_VERSION" "semgrep:semgrep:$AUDIT_SEMGREP_VERSION"; do
  bin="${tool%%:*}"; rest="${tool#*:}"; pkg="${rest%%:*}"; ver="${rest##*:}"
  spec="$pkg"; [ -n "$ver" ] && spec="$pkg==$ver"
  if ! have "$bin"; then
    log "installing $bin${ver:+ (pinned $ver)}"
    # try pinned spec, then unpinned, across pipx then pip — so a bad pin still yields a tool
    if have pipx; then
      pipx install "$spec" >/dev/null 2>&1 || pip_user "$spec" \
        || pipx install "$pkg" >/dev/null 2>&1 || pip_user "$pkg" || log "WARN: $bin install failed"
    else
      pip_user "$spec" || pip_user "$pkg" || log "WARN: $bin install failed"
    fi
  fi
done
# solc-select helps Slither match project pragmas
have solc-select || pip_user solc-select || true

# --- Aderyn (Cyfrin, Rust static analyzer) — prefer prebuilt release binary ---
if ! have aderyn; then
  log "installing aderyn${AUDIT_ADERYN_VERSION:+ (pinned $AUDIT_ADERYN_VERSION)}"
  a="$(arch_token rust)"; pat="aderyn-${a}-unknown-linux-gnu\.tar\.xz"; url=""
  [ -n "$a" ] && [ -n "$AUDIT_ADERYN_VERSION" ] && url="$(gh_tagged_asset Cyfrin/aderyn "v$AUDIT_ADERYN_VERSION" "$pat")"
  [ -z "$url" ] && [ -n "$a" ] && url="$(gh_latest_asset Cyfrin/aderyn "$pat")"   # fall back to latest
  if [ -n "$url" ] && install_release_bin "$url" aderyn.tar.xz aderyn; then :
  elif have cargo && cargo install aderyn ${AUDIT_ADERYN_VERSION:+--version "$AUDIT_ADERYN_VERSION"} >/dev/null 2>&1; then :
  elif have cargo && cargo install aderyn >/dev/null 2>&1; then :
  else log "WARN: aderyn install failed (no prebuilt asset for $(uname -m); try: cargo install aderyn)"; fi
fi

# --- Medusa (Trail of Bits stateful fuzzer) — prefer prebuilt release binary ---
if ! have medusa; then
  log "installing medusa${AUDIT_MEDUSA_VERSION:+ (pinned $AUDIT_MEDUSA_VERSION)}"
  a="$(arch_token go)"; pat="medusa-linux-${a}\.tar\.gz"; url=""
  [ -n "$a" ] && [ -n "$AUDIT_MEDUSA_VERSION" ] && url="$(gh_tagged_asset crytic/medusa "v$AUDIT_MEDUSA_VERSION" "$pat")"
  [ -z "$url" ] && [ -n "$a" ] && url="$(gh_latest_asset crytic/medusa "$pat")"   # fall back to latest
  if [ -n "$url" ] && install_release_bin "$url" medusa.tar.gz medusa; then :
  elif have go && go install "github.com/crytic/medusa@${AUDIT_MEDUSA_VERSION:+v$AUDIT_MEDUSA_VERSION}" >/dev/null 2>&1; then :
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
# "ready" means the tool actually EXECUTES, not merely that it is on PATH. A broken binary
# (wrong solc, missing shared lib, half-installed) reports as missing so the pipeline knows
# to degrade instead of trusting a tool that will error on first use.
works() { # $1=binary — true only if it runs and answers --version/--help
  have "$1" || return 1
  "$1" --version >/dev/null 2>&1 || "$1" --help >/dev/null 2>&1
}
ready=""; missing=""; broken=""
for t in forge slither halmos aderyn medusa semgrep; do
  if works "$t"; then ready="$ready $t"
  elif have "$t"; then broken="$broken $t"; missing="$missing $t"
  else missing="$missing $t"; fi
done
log "ready:${ready:- none}"
[ -n "$broken" ]  && log "on PATH but not executing:$broken (broken install — check deps/version)"
[ -n "$missing" ] && log "missing:$missing (pipeline degrades gracefully; rerun this hook to retry)"
exit 0
