#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-live-scroll-test}
SESSION=${NEWMUX_LIVE_SCROLL_SESSION:-newmux-live-scroll}

NEWMUX_SOCKET="$SOCKET_NAME" "$ROOT/scripts/start-newmux-fresh.sh" kill-only >/dev/null 2>&1 || true

NEWMUX_SOCKET="$SOCKET_NAME"
export NEWMUX_SOCKET

"$ROOT/scripts/run-newmux.sh" new-session -d -s "$SESSION" -n main

(
	sleep 1
	"$ROOT/scripts/seed-live-scroll-test.sh" "$SESSION:main"
) >/dev/null 2>&1 &

exec "$ROOT/scripts/run-newmux.sh" attach-session -t "$SESSION"
