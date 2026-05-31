#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

NEWMUX_SOCKET=${NEWMUX_SOCKET:-newmux-live-scroll-test}
export NEWMUX_SOCKET

exec "$ROOT/scripts/bench-current-newmux.sh" "$@"
