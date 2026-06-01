#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-codex-resume-test}
SESSION=${NEWMUX_CODEX_RESUME_SESSION:-newmux-codex-resume}

NEWMUX_SOCKET="$SOCKET_NAME" "$ROOT/scripts/start-newmux-fresh.sh" kill-only >/dev/null 2>&1 || true

NEWMUX_SOCKET="$SOCKET_NAME"
export NEWMUX_SOCKET

"$ROOT/scripts/run-newmux.sh" new-session -d -s "$SESSION" -n main

(
	"$ROOT/scripts/seed-codex-resume-test.sh" "$SESSION:main"
) >/dev/null 2>&1 &

exec "$ROOT/scripts/run-newmux.sh" attach-session -t "$SESSION"
