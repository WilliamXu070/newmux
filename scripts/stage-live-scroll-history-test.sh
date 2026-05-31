#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NEWMUX="$ROOT/bin/newmux"
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-live-scroll-test}
TARGET=${1:-newmux-live-scroll:main}
SCROLL_LINES=${SCROLL_LINES:-3}
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-30}
CAPTURE_FILE="${TMPDIR:-/tmp}/newmux-live-scroll-stage-$$.txt"

wait_for_animation()
{
	i=0
	limit=$((TIMEOUT_SECONDS * 2))
	while [ "$i" -lt "$limit" ]; do
		if "$NEWMUX" -L "$SOCKET_NAME" capture-pane -p -t "$TARGET" \
		    2>/dev/null | grep -q 'NEWMUX_ANIM frame='; then
			return
		fi
		sleep 0.5
		i=$((i + 1))
	done
	echo "NEWMUX_ANIM did not appear within ${TIMEOUT_SECONDS}s" >&2
	exit 1
}

stage_scroll()
{
	"$NEWMUX" -L "$SOCKET_NAME" copy-mode -LH -t "$TARGET"
	"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$TARGET" -X history-bottom
	"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$TARGET" -N "$SCROLL_LINES" \
		-X scroll-up
}

wait_for_animation
stage_scroll

i=0
while [ "$i" -lt 10 ]; do
	mode=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p -t "$TARGET" \
		'#{pane_in_mode}')
	scroll=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p -t "$TARGET" \
		'#{scroll_position}')
	if [ "$mode" = 1 ] && [ "$scroll" = "$SCROLL_LINES" ]; then
		"$NEWMUX" -L "$SOCKET_NAME" capture-pane -p -t "$TARGET" \
			>"$CAPTURE_FILE"
		anim_line=$(grep 'NEWMUX_ANIM frame=' "$CAPTURE_FILE" | tail -1 ||
			true)
		padding_visible=$(grep -o 'NEWMUX_ANIM_PADDING_[0-9][0-9]' \
			"$CAPTURE_FILE" | sed 's/.*_//' | tr '\n' ' ' |
			sed 's/[[:space:]]*$//')
		padding_count=$(grep -c 'NEWMUX_ANIM_PADDING_[0-9][0-9]' \
			"$CAPTURE_FILE" || true)
		last_padding=$(grep -o 'NEWMUX_ANIM_PADDING_[0-9][0-9]' \
			"$CAPTURE_FILE" | tail -1 | sed 's/.*_//' || true)
		if [ -z "$anim_line" ]; then
			echo "staged scroll hid NEWMUX_ANIM unexpectedly" >&2
			exit 1
		fi
		"$NEWMUX" -L "$SOCKET_NAME" display-message -t "$TARGET" \
			"live-scroll test ready: scroll=$scroll padding=$padding_visible"
		echo "live-scroll history animation test ready"
		echo "  socket=$SOCKET_NAME target=$TARGET scroll=$scroll mode=$mode"
		echo "  anim=$anim_line"
		echo "  visible_padding_count=$padding_count"
		echo "  visible_padding_rows=${padding_visible:-none}"
		echo "  bottom_visible_padding=${last_padding:-none}"
		rm -f "$CAPTURE_FILE"
		exit 0
	fi
	stage_scroll
	sleep 0.2
	i=$((i + 1))
done

echo "failed to stage live-scroll history test" >&2
echo "  mode=$mode scroll=$scroll expected_scroll=$SCROLL_LINES" >&2
exit 1
