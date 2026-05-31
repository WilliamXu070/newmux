#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NEWMUX="$ROOT/bin/newmux"
CONF="$ROOT/config/newmux-dev.tmux.conf"
SOCKET_NAME="newmux-append-bench-$$"
LOG_FILE="${TMPDIR:-/tmp}/newmux-append-bench-$$.log"
INITIAL_BLOCKS=${INITIAL_BLOCKS:-300}
APPEND_BLOCKS=${APPEND_BLOCKS:-200}
WIDTH=${WIDTH:-180}
HEIGHT=${HEIGHT:-48}
COPY_FLAGS=${COPY_FLAGS:--LH}

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

payload='
binmode STDOUT, ":encoding(UTF-8)";
$tri = chr(0xe0b0);
$folder = chr(0xf115);
$desktop = chr(0xf108);
$book = chr(0xf02d);
sub block {
	my ($i, $prefix) = @_;
	printf "%s~%s\n", $tri, $tri;
	printf "%s %s %160s %02d:%02d:%02d\n",
	    chr(0x276f), $prefix, "", ($i / 3600) % 24, ($i / 60) % 60, $i % 60;
	printf "%s Applications  bin  %s Desktop  %s Documents  Downloads  Library  Movies  Music  Pictures  Public  theos  tmp  Tracker  train_log.jsonl\n\n",
	    $folder, $desktop, $book;
}
for ($i = 1; $i <= $ENV{INITIAL_BLOCKS}; $i++) { block($i, "ls") }
$| = 1;
system($ENV{NEWMUX}, "-L", $ENV{SOCKET_NAME}, "wait-for", "-S", "initial-done");
sleep 1;
for ($i = 1; $i <= $ENV{APPEND_BLOCKS}; $i++) { block($i, "append-ls") }
system($ENV{NEWMUX}, "-L", $ENV{SOCKET_NAME}, "wait-for", "-S", "append-done");
sleep 5;
'

cmd="env NEWMUX=$NEWMUX SOCKET_NAME=$SOCKET_NAME INITIAL_BLOCKS=$INITIAL_BLOCKS APPEND_BLOCKS=$APPEND_BLOCKS perl -CS -e '$payload'"

"$NEWMUX" -L "$SOCKET_NAME" -f "$CONF" new-session -d -x "$WIDTH" -y "$HEIGHT" \
	-s append-bench -n fancy "$cmd"

script -q "$LOG_FILE" "$NEWMUX" -L "$SOCKET_NAME" attach-session -t append-bench >/dev/null 2>&1 &
SCRIPT_PID=$!
"$NEWMUX" -L "$SOCKET_NAME" wait-for initial-done
sleep 0.1

"$NEWMUX" -L "$SOCKET_NAME" copy-mode "$COPY_FLAGS" -t append-bench:fancy
"$NEWMUX" -L "$SOCKET_NAME" send-keys -t append-bench:fancy -N "$((HEIGHT * 3))" \
	-X scroll-up

before_pos=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p -t append-bench:fancy \
	'#{scroll_position}')
elapsed=$(elapsed_ms "$NEWMUX" -L "$SOCKET_NAME" wait-for append-done)
after_pos=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p -t append-bench:fancy \
	'#{scroll_position}')

perl -e '
	my ($initial, $append, $height, $flags, $before, $after, $elapsed) = @ARGV;
	printf "newmux live append benchmark\n";
	printf "  initial_blocks=%s append_blocks=%s height=%s copy_flags=%s\n",
	    $initial, $append, $height, $flags;
	printf "  wait=%8.3f ms append_blocks/s=%8.1f scroll_before=%s scroll_after=%s\n",
	    $elapsed, $append / ($elapsed / 1000), $before, $after;
' "$INITIAL_BLOCKS" "$APPEND_BLOCKS" "$HEIGHT" "$COPY_FLAGS" "$before_pos" "$after_pos" "$elapsed"
