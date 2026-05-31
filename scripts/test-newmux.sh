#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NEWMUX="$ROOT/bin/newmux"
CONF="$ROOT/config/newmux-dev.tmux.conf"
SOCKET_NAME="newmux-test-$$"

if [ ! -x "$NEWMUX" ]; then
	"$ROOT/scripts/build-newmux.sh"
fi

cleanup()
{
	"$NEWMUX" -L "$SOCKET_NAME" kill-server >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

VERSION=$("$NEWMUX" -V)
case "$VERSION" in
	*"newmux-dev"*) ;;
	*)
		echo "unexpected version: $VERSION" >&2
		exit 1
		;;
esac

"$NEWMUX" -L "$SOCKET_NAME" -f "$CONF" new-session -d -s smoke -n main \
	'sleep 10'

SERVER_VERSION=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p '#{version}')
case "$SERVER_VERSION" in
	*"newmux-dev"*) ;;
	*)
		echo "server did not report newmux version: $SERVER_VERSION" >&2
		exit 1
		;;
esac

STATUS_LEFT=$("$NEWMUX" -L "$SOCKET_NAME" show-options -gqv status-left)
case "$STATUS_LEFT" in
	*"newmux"*) ;;
	*)
		echo "dev config did not load status-left: $STATUS_LEFT" >&2
		exit 1
		;;
esac

RESTORE_BIND=$("$NEWMUX" -L "$SOCKET_NAME" list-keys -T prefix | grep 'prefix T ')
case "$RESTORE_BIND" in
	*"future reopen-latest-closed"*) ;;
	*)
		echo "restore placeholder binding missing: $RESTORE_BIND" >&2
		exit 1
		;;
esac

COPY_MODE_BIND=$("$NEWMUX" -L "$SOCKET_NAME" list-keys -T prefix | grep 'prefix H ')
case "$COPY_MODE_BIND" in
	*"copy-mode -Le"*) ;;
	*)
		echo "copy-mode binding missing: $COPY_MODE_BIND" >&2
		exit 1
		;;
esac

WHEEL_BIND=$("$NEWMUX" -L "$SOCKET_NAME" list-keys -T root | grep 'WheelUpPane')
case "$WHEEL_BIND" in
	*"#{>:#{history_size},0}"*"copy-mode -Le"*) ;;
	*)
		echo "wheel binding does not guard empty history: $WHEEL_BIND" >&2
		exit 1
		;;
esac

"$NEWMUX" -L "$SOCKET_NAME" new-window -t smoke: -n no-history \
	'sh -c "printf no-history; sleep 2"'
sleep 0.2
NO_HISTORY_PANE=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p \
	-t smoke:no-history '#{pane_id}')
"$NEWMUX" -L "$SOCKET_NAME" copy-mode -L -t "$NO_HISTORY_PANE"
NO_HISTORY_CURSOR_BEFORE=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p \
	-t "$NO_HISTORY_PANE" '#{copy_cursor_y}')
"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$NO_HISTORY_PANE" -X scroll-up
NO_HISTORY_SCROLL_AFTER=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p \
	-t "$NO_HISTORY_PANE" '#{scroll_position}')
NO_HISTORY_CURSOR_AFTER=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p \
	-t "$NO_HISTORY_PANE" '#{copy_cursor_y}')
if [ "$NO_HISTORY_SCROLL_AFTER" != 0 ] ||
    [ "$NO_HISTORY_CURSOR_AFTER" != "$NO_HISTORY_CURSOR_BEFORE" ]; then
	echo "live copy-mode moved on empty history scroll" >&2
	echo "scroll=$NO_HISTORY_SCROLL_AFTER before=$NO_HISTORY_CURSOR_BEFORE after=$NO_HISTORY_CURSOR_AFTER" >&2
	exit 1
fi

"$NEWMUX" -L "$SOCKET_NAME" new-window -t smoke: -n live \
	'sh -c "printf \"before-live\\n\"; sleep 0.2; printf \"after-live\\n\"; sleep 2"'
sleep 0.1
"$NEWMUX" -L "$SOCKET_NAME" copy-mode -L -t smoke:live
sleep 0.5
LIVE_CAPTURE=$("$NEWMUX" -L "$SOCKET_NAME" capture-pane -p -t smoke:live)
case "$LIVE_CAPTURE" in
	*"after-live"*) ;;
	*)
		echo "live copy-mode did not render new output after entry" >&2
		echo "$LIVE_CAPTURE" >&2
		exit 1
		;;
esac

"$NEWMUX" -L "$SOCKET_NAME" new-window -t smoke: -n live-resize \
	'sh -c "awk '\''BEGIN { for (i = 1; i <= 80; i++) printf \"resize-line-%03d\\n\", i }'\''; sleep 2"'
sleep 0.5
LIVE_RESIZE_PANE=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p \
	-t smoke:live-resize '#{pane_id}')
"$NEWMUX" -L "$SOCKET_NAME" copy-mode -L -t "$LIVE_RESIZE_PANE"
"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$LIVE_RESIZE_PANE" -X page-up
RESIZE_SCROLL_BEFORE=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p \
	-t "$LIVE_RESIZE_PANE" '#{scroll_position}')
case "$RESIZE_SCROLL_BEFORE" in
	0|"")
		echo "live copy-mode did not scroll before resize" >&2
		exit 1
		;;
esac
"$NEWMUX" -L "$SOCKET_NAME" resize-window -t smoke:live-resize -x 100 -y 30
RESIZE_SCROLL_AFTER=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p \
	-t "$LIVE_RESIZE_PANE" '#{scroll_position}')
case "$RESIZE_SCROLL_AFTER" in
	0|"")
		echo "live copy-mode lost scroll position after resize" >&2
		exit 1
		;;
esac

echo "newmux smoke tests passed"
echo "  binary: $VERSION"
echo "  server: $SERVER_VERSION"
