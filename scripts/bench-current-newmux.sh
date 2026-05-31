#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NEWMUX="$ROOT/bin/newmux"
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-dev}
TARGET=${1:-}
COPY_FLAGS=${COPY_FLAGS:--LH}
PASSES=${PASSES:-3}
STEPS=${STEPS:-}

elapsed_ms()
{
	perl -MTime::HiRes=time -e '
		my $start = time;
		system(@ARGV) == 0 or exit 1;
		printf "%.3f\n", (time - $start) * 1000;
	' "$@"
}

tmux_cmd()
{
	if [ -n "$TARGET" ]; then
		"$NEWMUX" -L "$SOCKET_NAME" "$@" -t "$TARGET"
	else
		"$NEWMUX" -L "$SOCKET_NAME" "$@"
	fi
}

display()
{
	if [ -n "$TARGET" ]; then
		"$NEWMUX" -L "$SOCKET_NAME" display-message -p -t "$TARGET" "$1"
	else
		"$NEWMUX" -L "$SOCKET_NAME" display-message -p "$1"
	fi
}

send_copy()
{
	if [ -n "$TARGET" ]; then
		"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$TARGET" "$@"
	else
		"$NEWMUX" -L "$SOCKET_NAME" send-keys "$@"
	fi
}

ensure_bottom()
{
	tmux_cmd copy-mode "$COPY_FLAGS" >/dev/null
	send_copy -X history-bottom >/dev/null
}

finish_bottom()
{
	ensure_bottom
	send_copy -X cancel >/dev/null 2>&1 || true
}

history_size=$(display '#{history_size}')
if [ "${history_size:-0}" -le 0 ]; then
	echo "target pane has no scrollback history" >&2
	exit 1
fi

if [ -z "$STEPS" ]; then
	STEPS=$history_size
	if [ "$STEPS" -gt 900 ]; then
		STEPS=900
	fi
	if [ "$STEPS" -lt 1 ]; then
		STEPS=1
	fi
fi

target_label=$(display '#{session_name}:#{window_index}.#{pane_index} #{pane_id}')
echo "newmux tmux scroll command timing"
echo "  socket=$SOCKET_NAME target=$target_label history=$history_size steps=$STEPS passes=$PASSES copy_flags=$COPY_FLAGS"
echo "  note=measures tmux copy-mode scroll command cost, not physical trackpad FPS"

pass=1
while [ "$pass" -le "$PASSES" ]; do
	ensure_bottom
	up_ms=$(elapsed_ms "$NEWMUX" -L "$SOCKET_NAME" send-keys \
		${TARGET:+-t "$TARGET"} -N "$STEPS" -X scroll-up)
	up_pos=$(display '#{scroll_position}')

	ensure_bottom
	send_copy -N "$STEPS" -X scroll-up >/dev/null
	down_ms=$(elapsed_ms "$NEWMUX" -L "$SOCKET_NAME" send-keys \
		${TARGET:+-t "$TARGET"} -N "$STEPS" -X scroll-down)
	down_pos=$(display '#{scroll_position}')

	perl -e '
		my ($pass, $steps, $up, $down, $up_pos, $down_pos) = @ARGV;
		printf "pass=%d up=%8.3f ms (%8.1f lines/s) scroll=%s  down=%8.3f ms (%8.1f lines/s) scroll=%s\n",
		    $pass, $up, $steps / ($up / 1000), $up_pos, $down,
		    $steps / ($down / 1000), $down_pos;
' "$pass" "$STEPS" "$up_ms" "$down_ms" "$up_pos" "$down_pos"

	pass=$((pass + 1))
done

finish_bottom
