#!/usr/bin/env bash
# formalize_ship.sh <problem-id> <statement.lean> [notes.txt]
# Runs the site's checker on a statement file (it only proves that it compiles), pushes a one-file branch to the fork,
# queues it so the fork's workflow opens the PR upstream, waits for the PR, releases the lease as submitted.
# notes.txt (optional) is appended to the PR body for the human reviewer: say how each part of the source was formalized.
# Exit: 0 submitted | 4 checker rejected | 3 queued, PR not seen yet | 1 setup problem.
set -uo pipefail
ID="${1:?problem id}"; FILE="${2:?statement file}"; NOTES="${3:-}"
WORK="${WORK:-$HOME/oma-work}"; FORK="${FORK:-/home/user/open-math-agents}"
UP=https://github.com/GuillaumeBAUD-coder/open-math-agents; HANDLE=eitanteperman
EMAIL=276188423+eitanteperman@users.noreply.github.com
export PATH="$HOME/.elan/bin:$PATH"
SAFE=$(printf '%s' "$ID" | tr -c 'A-Za-z0-9._-' '_')
LEASE=$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1])).get("lease") or "")' "$WORK/leases/fz_$SAFE.json" 2>/dev/null)
[ -n "$LEASE" ] || { echo "NO_LEASE: run formalize_claim.sh $ID first"; exit 1; }
release() { curl -sS -m 30 -o /dev/null -X POST "https://lefttosolve.com/api/desk/release?lease=$LEASE&reason=$1" || true; }
commit() {
  if [ -n "${TRAILER:-}" ]; then git -c user.name="$HANDLE" -c user.email="$EMAIL" commit -q -m "$1" -m "$TRAILER"
  else git -c user.name="$HANDLE" -c user.email="$EMAIL" commit -q -m "$1"; fi
}
mkdir -p "$WORK/oma/statements"; cp "$FILE" "$WORK/oma/statements/$ID.lean"
(cd "$WORK/oma" && OMA_FC="$WORK/oma/.oma/formal-conjectures" tools/check.sh "statements/$ID.lean" "$WORK/verdict_fz_$SAFE.json") >/dev/null 2>&1
VERDICT=$(python3 -I -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d["verdict"],"|",d["reason"]);print(d["log"][-1500:] if d["verdict"]!="accepted" else "")' "$WORK/verdict_fz_$SAFE.json" 2>/dev/null || echo "none | no verdict")
case "$VERDICT" in accepted*) ;; *) echo "CHECK_FAILED $ID: $VERDICT"; exit 4 ;; esac   # lease kept so you can fix and retry
cd "$FORK" || exit 1
git fetch -q --depth 1 "$UP" main && git checkout -q -B "oma/stmt-$SAFE" FETCH_HEAD
mkdir -p statements && cp "$WORK/oma/statements/$ID.lean" "statements/$ID.lean" && git add "statements/$ID.lean"
commit "statement: $ID"
SHA=$(git rev-parse HEAD)
for i in 1 2 3 4; do git -c push.negotiate=true push -q -f -u origin "oma/stmt-$SAFE" && break; sleep $((i * 2)); done
git checkout -q main && git fetch -q origin main && git reset -q --hard origin/main
FOOT="${PR_FOOTER:-🤖 Generated with [Claude Code](https://claude.com/claude-code)}"
{
  printf '%s\n%s\nLease: %s\nAgent: claude-code\n\nProblem: https://lefttosolve.com/p/%s\nChecked locally with tools/check.sh: the statement compiles (needs human review of the translation).\n' "oma/stmt-$SAFE" "$ID" "$LEASE" "$ID"
  if [ -n "$NOTES" ] && [ -f "$NOTES" ]; then printf '\nHow the source was formalized:\n'; cat "$NOTES"; fi
  printf '\n%s\n' "$FOOT"
} > "oma-queue/stmt_$SAFE.txt"
git add "oma-queue/stmt_$SAFE.txt" && commit "queue: statement $ID"
for i in 1 2 3 4; do git -c push.negotiate=true push -q origin main && break; sleep $((i * 2)); git fetch -q origin main && git rebase -q origin/main; done
PR=""
for i in $(seq 1 30); do
  PR=$(git ls-remote "$UP" 'refs/pull/*/head' 2>/dev/null | grep "^$SHA" | awk '{print $2}' | head -n 1 || true)
  [ -n "$PR" ] && break
  curl -sS -m 30 -o /dev/null -X POST "https://lefttosolve.com/api/desk/beat?lease=$LEASE" || true
  sleep 10
done
if [ -n "$PR" ]; then release submitted; echo "SUBMITTED statement $ID as PR $(echo "$PR" | sed 's#refs/pull/\([0-9]*\)/head#\1#')"
else echo "PENDING statement $ID: pushed and queued, no PR seen after 5 min (lease kept; check the fork's Actions tab)"; exit 3; fi
