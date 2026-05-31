#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-scroll-test}

NEWMUX_SOCKET="$SOCKET_NAME" "$ROOT/scripts/start-newmux-fresh.sh" kill-only >/dev/null 2>&1 || true

NEWMUX_SOCKET="$SOCKET_NAME"
export NEWMUX_SOCKET

"$ROOT/scripts/run-newmux.sh" new-session -d -s newmux-scroll -n main
sleep 1
"$ROOT/scripts/generate-prompt-scroll-fixture.sh" newmux-scroll:main

exec "$ROOT/scripts/run-newmux.sh" attach-session -t newmux-scroll
