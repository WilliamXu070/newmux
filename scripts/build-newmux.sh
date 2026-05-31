#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SRC="$ROOT/tmux"
PREFIX="$ROOT/.local/newmux"
JOBS=${JOBS:-}

if [ ! -d "$SRC" ]; then
	echo "tmux source not found at $SRC" >&2
	exit 1
fi

if command -v brew >/dev/null 2>&1; then
	BREW_PREFIX=$(brew --prefix)
	export PKG_CONFIG_PATH="$BREW_PREFIX/opt/libevent/lib/pkgconfig:$BREW_PREFIX/opt/ncurses/lib/pkgconfig:$BREW_PREFIX/opt/utf8proc/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
	export CPPFLAGS="-I$BREW_PREFIX/opt/libevent/include -I$BREW_PREFIX/opt/ncurses/include -I$BREW_PREFIX/opt/utf8proc/include ${CPPFLAGS:-}"
	export LDFLAGS="-L$BREW_PREFIX/opt/libevent/lib -L$BREW_PREFIX/opt/ncurses/lib -L$BREW_PREFIX/opt/utf8proc/lib ${LDFLAGS:-}"
fi

if [ -z "$JOBS" ]; then
	if command -v sysctl >/dev/null 2>&1; then
		JOBS=$(sysctl -n hw.ncpu)
	elif command -v nproc >/dev/null 2>&1; then
		JOBS=$(nproc)
	else
		JOBS=4
	fi
fi

cd "$SRC"

if [ ! -x ./configure ] || [ Makefile.am -nt Makefile.in ]; then
	./autogen.sh
fi

./configure --prefix="$PREFIX" --enable-debug --enable-utf8proc
make -j"$JOBS"
make install

mkdir -p "$ROOT/bin"
cp "$PREFIX/bin/tmux" "$ROOT/bin/newmux"
if command -v codesign >/dev/null 2>&1; then
	codesign --force --sign - "$ROOT/bin/newmux" >/dev/null 2>&1 || true
fi

echo "Built $ROOT/bin/newmux"
"$ROOT/bin/newmux" -V
