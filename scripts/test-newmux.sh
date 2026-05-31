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
	*"copy-mode -e"*) ;;
	*)
		echo "copy-mode binding missing: $COPY_MODE_BIND" >&2
		exit 1
		;;
esac

echo "newmux smoke tests passed"
echo "  binary: $VERSION"
echo "  server: $SERVER_VERSION"
