#!/usr/bin/env bash
# Idempotent environment setup for the lefttosolve workflow. Prints READY at the end.
# Needs about 10 GB of disk and several minutes the first time. Safe to re-run if it times out.
set -euo pipefail
WORK="${WORK:-$HOME/oma-work}"; mkdir -p "$WORK"
export PATH="$HOME/.elan/bin:$PATH"
if ! command -v lake >/dev/null 2>&1; then
  d=$(mktemp -d)
  curl -sSfL -o "$d/elan.tar.gz" https://github.com/leanprover/elan/releases/latest/download/elan-x86_64-unknown-linux-gnu.tar.gz
  tar xzf "$d/elan.tar.gz" -C "$d"
  "$d/elan-init" -y --default-toolchain none >/dev/null 2>&1
fi
# the site's own tools (checker, linter, catalog) from upstream main
[ -d "$WORK/oma/.git" ] || git clone -q --depth 1 https://github.com/GuillaumeBAUD-coder/open-math-agents.git "$WORK/oma"
git -C "$WORK/oma" fetch -q --depth 1 origin main
git -C "$WORK/oma" reset -q --hard FETCH_HEAD
WANT=$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1]))["meta"]["upstreamCommit"])' "$WORK/oma/data/catalog.json")
FC="$WORK/oma/.oma/formal-conjectures"
mkdir -p "$WORK/oma/.oma"
[ -d "$FC/.git" ] || git clone -q --filter=blob:none https://github.com/google-deepmind/formal-conjectures "$FC"
if [ "$(git -C "$FC" rev-parse HEAD)" != "$WANT" ]; then
  git -C "$FC" fetch -q --depth 1 origin "$WANT" || git -C "$FC" fetch -q origin
  git -C "$FC" checkout -q "$WANT"
fi
(cd "$FC" && lake exe cache get 2>&1 | tail -n 1)
mkdir -p "$WORK/leases" "$WORK/wip"
echo "READY (formal-conjectures at ${WANT:0:12}, WORK=$WORK)"
