#!/usr/bin/env bash
# ship.sh <problem-id> <proof.lean>
#   <proof.lean> is a proof that already compiles in a scratch file: first line = the import line, then the body
#   (open ..., helper lemmas, and: theorem OMA.solution : type_of% @<decl> := by ...).
# It claims the problem on lefttosolve as eitanteperman, rebuilds the file with the site's official header, runs the
# site's own checker, pushes a one-file branch (based on upstream main) to the fork, queues it so the fork's
# open-proof-prs workflow opens the pull request upstream, waits for the PR, then marks the lease submitted.
# Optional env: WORK (default ~/oma-work), FORK (default /home/user/open-math-agents),
#               TRAILER (commit trailer lines), PR_FOOTER (last lines of the PR body).
# Exit codes: 0 submitted (PR number printed) | 2 could not claim | 4 checker rejected | 3 queued, PR not seen yet.
set -uo pipefail
ID="${1:?problem id}"; PROOF="${2:?proof file}"
WORK="${WORK:-$HOME/oma-work}"; FORK="${FORK:-/home/user/open-math-agents}"
UP=https://github.com/GuillaumeBAUD-coder/open-math-agents
HANDLE=eitanteperman
EMAIL=276188423+eitanteperman@users.noreply.github.com
export PATH="$HOME/.elan/bin:$PATH"
SAFE=$(printf '%s' "$ID" | tr -c 'A-Za-z0-9._-' '_')
enc() { python3 -I -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$1"; }
release() { curl -sS -m 30 -o /dev/null -X POST "https://lefttosolve.com/api/desk/release?lease=$LEASE&reason=$1" || true; }
commit() {
  if [ -n "${TRAILER:-}" ]; then git -c user.name="$HANDLE" -c user.email="$EMAIL" commit -q -m "$1" -m "$TRAILER"
  else git -c user.name="$HANDLE" -c user.email="$EMAIL" commit -q -m "$1"; fi
}
mkdir -p "$WORK/leases"
curl -sS -m 30 "https://lefttosolve.com/api/desk/next?handle=$HANDLE&agent=claude-code&problem=$(enc "$ID")" -o "$WORK/leases/$SAFE.json"
LEASE=$(python3 -I -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("lease") or "")
except Exception: print("")' "$WORK/leases/$SAFE.json")
if [ -z "$LEASE" ]; then echo "CLAIM_FAILED $ID: $(head -c 300 "$WORK/leases/$SAFE.json")"; exit 2; fi
python3 -I - "$WORK/leases/$SAFE.json" "$PROOF" "$WORK/oma/proofs/$ID.lean" <<'PY'
import json, sys
head = json.load(open(sys.argv[1]))["skeleton"].split("theorem OMA.solution")[0].rstrip()
lines = open(sys.argv[2]).read().split("\n")[1:]
while lines and not lines[0].strip(): lines.pop(0)
open(sys.argv[3], "w").write(head + "\n\n" + "\n".join(lines).rstrip() + "\n")
PY
(cd "$WORK/oma" && OMA_FC="$WORK/oma/.oma/formal-conjectures" tools/check.sh "proofs/$ID.lean" "$WORK/verdict_$SAFE.json") >/dev/null 2>&1
VERDICT=$(python3 -I -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d["verdict"],"|",d["reason"])' "$WORK/verdict_$SAFE.json" 2>/dev/null || echo "none | no verdict")
case "$VERDICT" in
  accepted*) ;;
  *) echo "CHECK_FAILED $ID: $VERDICT"; release other; exit 4 ;;
esac
cd "$FORK" || exit 1
git fetch -q --depth 1 "$UP" main && git checkout -q -B "oma/$SAFE" FETCH_HEAD
cp "$WORK/oma/proofs/$ID.lean" "proofs/$ID.lean" && git add "proofs/$ID.lean"
commit "proof: $ID"
SHA=$(git rev-parse HEAD)
for i in 1 2 3 4; do git -c push.negotiate=true push -q -f -u origin "oma/$SAFE" && break; sleep $((i * 2)); done
git checkout -q main && git fetch -q origin main && git reset -q --hard origin/main
FOOT="${PR_FOOTER:-🤖 Generated with [Claude Code](https://claude.com/claude-code)}"
printf '%s\n%s\nLease: %s\nAgent: claude-code\n\nProblem: https://lefttosolve.com/p/%s\nChecked locally with tools/check.sh: accepted (axioms: propext, Classical.choice, Quot.sound).\n\n%s\n' \
  "oma/$SAFE" "$ID" "$LEASE" "$ID" "$FOOT" > "oma-queue/$SAFE.txt"
git add "oma-queue/$SAFE.txt" && commit "queue: $ID"
for i in 1 2 3 4; do git -c push.negotiate=true push -q origin main && break; sleep $((i * 2)); git fetch -q origin main && git rebase -q origin/main; done
PR=""
for i in $(seq 1 30); do
  PR=$(git ls-remote "$UP" 'refs/pull/*/head' 2>/dev/null | grep "^$SHA" | awk '{print $2}' | head -n 1 || true)
  [ -n "$PR" ] && break
  curl -sS -m 30 -o /dev/null -X POST "https://lefttosolve.com/api/desk/beat?lease=$LEASE" || true
  sleep 10
done
if [ -n "$PR" ]; then
  release submitted
  echo "SUBMITTED $ID as PR $(echo "$PR" | sed 's#refs/pull/\([0-9]*\)/head#\1#')"
else
  echo "$LEASE" >> "$WORK/held_leases.txt"
  echo "PENDING $ID: pushed and queued, but no PR seen after 5 min (lease $LEASE kept; check the fork's Actions tab)"
  exit 3
fi
