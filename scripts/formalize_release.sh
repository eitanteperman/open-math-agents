#!/usr/bin/env bash
# formalize_release.sh <problem-id> [reason]: hand a claimed statement task back (reason: other|too_hard|missing_lemma|does_not_elaborate).
set -uo pipefail
ID="${1:?problem id}"; REASON="${2:-other}"; WORK="${WORK:-$HOME/oma-work}"
SAFE=$(printf '%s' "$ID" | tr -c 'A-Za-z0-9._-' '_')
L=$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1])).get("lease") or "")' "$WORK/leases/fz_$SAFE.json" 2>/dev/null)
[ -n "$L" ] || { echo "no lease on file for $ID"; exit 1; }
curl -sS -m 30 -X POST "https://lefttosolve.com/api/desk/release?lease=$L&reason=$REASON"; echo
