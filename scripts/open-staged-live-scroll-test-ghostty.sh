#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-live-scroll-test}

NEWMUX_SOCKET="$SOCKET_NAME" "$ROOT/scripts/start-newmux-fresh.sh" kill-only

PIDS=$(ps ax -o pid=,command= | awk \
	'/ghostty-live-scroll-test.config/ && !/awk/ { print $1 }')
if [ -n "$PIDS" ]; then
	kill $PIDS >/dev/null 2>&1 || true
fi

NEWMUX_SOCKET="$SOCKET_NAME" "$ROOT/scripts/open-live-scroll-test-ghostty.sh"
NEWMUX_SOCKET="$SOCKET_NAME" "$ROOT/scripts/stage-live-scroll-history-test.sh"
NEWMUX_SOCKET="$SOCKET_NAME" "$ROOT/scripts/probe-live-scroll-ui.sh"
