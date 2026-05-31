#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NEWMUX="$ROOT/bin/newmux"
CONF="$ROOT/config/newmux-dev.tmux.conf"
SOCKET_NAME="newmux-bench-$$"
LOG_FILE="${TMPDIR:-/tmp}/newmux-bench-script-$$.log"
LINES=${LINES:-3000}
STEPS=${STEPS:-900}
WIDTH=${WIDTH:-180}
HEIGHT=${HEIGHT:-48}
COPY_FLAGS=${COPY_FLAGS:--L}

if [ ! -x "$NEWMUX" ]; then
	"$ROOT/scripts/build-newmux.sh"
fi

cleanup()
{
	if [ -n "${SCRIPT_PID:-}" ]; then
		kill "$SCRIPT_PID" >/dev/null 2>&1 || true
		wait "$SCRIPT_PID" >/dev/null 2>&1 || true
	fi
	"$NEWMUX" -L "$SOCKET_NAME" kill-server >/dev/null 2>&1 || true
	rm -f "$LOG_FILE"
}
trap cleanup EXIT INT TERM

elapsed_ms()
{
	perl -MTime::HiRes=time -e '
		my $start = time;
		system(@ARGV) == 0 or exit 1;
		printf "%.3f\n", (time - $start) * 1000;
	' "$@"
}

plain_cmd='env LINES='"$LINES"' perl -e '\''for ($i = 1; $i <= $ENV{LINES}; $i++) { printf "plain-line-%05d abcdefghijklmnopqrstuvwxyz 0123456789 abcdefghijklmnopqrstuvwxyz\n", $i } sleep 30'\'''
fancy_cmd='env LINES='"$LINES"' perl -CS -e '\''binmode STDOUT, ":encoding(UTF-8)"; $tri = chr(0xe0b0); $folder = chr(0xf115); $desktop = chr(0xf108); $book = chr(0xf02d); for ($i = 1; $i <= $ENV{LINES}; $i++) { printf "%s~%s\n%s ls %160s %02d:%02d:%02d\n%s Applications  bin  %s Desktop  %s Documents  Downloads  Library  Movies  Music  Pictures  Public  train_log.jsonl\n\n", $tri, $tri, chr(0x276f), "", ($i / 3600) % 24, ($i / 60) % 60, $i % 60, $folder, $desktop, $book } sleep 30'\'''

"$NEWMUX" -L "$SOCKET_NAME" -f "$CONF" new-session -d -x "$WIDTH" -y "$HEIGHT" \
	-s bench -n plain "$plain_cmd"
"$NEWMUX" -L "$SOCKET_NAME" new-window -t bench: -n fancy "$fancy_cmd"

script -q "$LOG_FILE" "$NEWMUX" -L "$SOCKET_NAME" attach-session -t bench >/dev/null 2>&1 &
SCRIPT_PID=$!
sleep 1

bench_window()
{
	name=$1
	target="bench:$name"

	"$NEWMUX" -L "$SOCKET_NAME" select-window -t "$target"
	sleep 0.1
	"$NEWMUX" -L "$SOCKET_NAME" copy-mode "$COPY_FLAGS" -t "$target"

	up_ms=$(elapsed_ms "$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$target" \
		-N "$STEPS" -X scroll-up)
	pos=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p -t "$target" \
		'#{scroll_position}')
	down_ms=$(elapsed_ms "$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$target" \
		-N "$STEPS" -X scroll-down)

	perl -e '
		my ($name, $steps, $up, $down, $pos) = @ARGV;
		printf "%-6s up=%8.3f ms (%8.1f lines/s) down=%8.3f ms (%8.1f lines/s) scroll=%s\n",
		    $name, $up, $steps / ($up / 1000), $down,
		    $steps / ($down / 1000), $pos;
	' "$name" "$STEPS" "$up_ms" "$down_ms" "$pos"

	"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$target" q
}

echo "newmux live scroll benchmark"
echo "  lines=$LINES steps=$STEPS size=${WIDTH}x${HEIGHT} copy_flags=$COPY_FLAGS"
bench_window plain
bench_window fancy
