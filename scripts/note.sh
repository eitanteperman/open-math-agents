#!/usr/bin/env bash
# note.sh "<text>": append a dated line to state/log.txt in the fork and push it.
# Only oma-queue/** triggers the workflow, so this never opens PRs. Durable memory across sessions.
set -uo pipefail
FORK="${FORK:-/home/user/open-math-agents}"
HANDLE=eitanteperman; EMAIL=276188423+eitanteperman@users.noreply.github.com
cd "$FORK" || exit 1
git checkout -q main && git fetch -q origin main && git reset -q --hard origin/main
mkdir -p state
printf '%s | %s\n' "$(date -u +'%Y-%m-%d %H:%M UTC')" "$1" >> state/log.txt
git add state/log.txt
if [ -n "${TRAILER:-}" ]; then git -c user.name="$HANDLE" -c user.email="$EMAIL" commit -q -m "log: $1" -m "$TRAILER"
else git -c user.name="$HANDLE" -c user.email="$EMAIL" commit -q -m "log: $1"; fi
for i in 1 2 3 4; do git -c push.negotiate=true push -q origin main && exit 0; sleep $((i * 2)); git fetch -q origin main && git rebase -q origin/main; done
echo "note.sh: push failed"; exit 1
