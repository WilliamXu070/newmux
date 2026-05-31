#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

exec "$ROOT/scripts/open-live-scroll-test-ghostty.sh"
