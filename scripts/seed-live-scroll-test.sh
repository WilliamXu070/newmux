#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NEWMUX="$ROOT/bin/newmux"
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-live-scroll-test}
TARGET=${1:-newmux-live-scroll:main}
LS_RUNS=${LS_RUNS:-80}
DOC_LINES=${DOC_LINES:-500}
DOC_FILE="$ROOT/.local/live-scroll-test/latest/newmux-live-scroll-doc.txt"

make_doc()
{
	mkdir -p "$(dirname "$DOC_FILE")"
	i=1
	while [ "$i" -le "$DOC_LINES" ]; do
		printf 'doc-line-%03d abcdefghijklmnopqrstuvwxyz 0123456789 abcdefghijklmnopqrstuvwxyz\n' "$i"
		i=$((i + 1))
	done >"$DOC_FILE"
}

send_line()
{
	"$NEWMUX" -L "$SOCKET_NAME" send-keys -l -t "$PANE" "$1"
	"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$PANE" C-m
}

send_marker()
{
	send_line "printf '\\n### $1 ###\\n'"
}

send_wait()
{
	label=$1
	send_line "\"$NEWMUX\" -L \"$SOCKET_NAME\" wait-for -S live-scroll-${label}"
	"$NEWMUX" -L "$SOCKET_NAME" wait-for "live-scroll-${label}"
}

wait_for_shell()
{
	i=1
	while [ "$i" -le 50 ]; do
		if "$NEWMUX" -L "$SOCKET_NAME" display-message -p -t "$TARGET" \
		    '#{pane_id}' >/dev/null 2>&1; then
			return
		fi
		sleep 0.1
		i=$((i + 1))
	done
	echo "target pane is not ready: $TARGET" >&2
	exit 1
}

make_doc
wait_for_shell
PANE=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p -t "$TARGET" '#{pane_id}')

sleep 0.8
send_marker NEWMUX_LIVE_SCROLL_REAL_PROFILE
send_line "printf 'Real shell/profile live-scroll test. Repeated ls + document output + running animation.\\n'"
send_line "printf 'After NEWMUX_LIVE_SCROLL_READY, press Cmd+Shift+H and physically scroll up.\\n'"
send_wait intro

send_marker NEWMUX_LIVE_SCROLL_LS_START
i=1
while [ "$i" -le "$LS_RUNS" ]; do
	send_line ls
	sleep 0.03
	i=$((i + 1))
done
send_wait ls

send_marker NEWMUX_LIVE_SCROLL_DOC_START
send_line "cat '$DOC_FILE'"
send_wait doc

send_marker NEWMUX_LIVE_SCROLL_READY
send_line "printf '\\nReady. Press Cmd+Shift+H, scroll up 2-3 lines, and watch NEWMUX_ANIM while bottom padding is offscreen.\\n'"
send_line "printf 'Timing metric: NEWMUX_SOCKET=$SOCKET_NAME ./scripts/bench-current-newmux.sh\\n'"
send_wait ready
send_line "$ROOT/scripts/live-scroll-animation.sh"
