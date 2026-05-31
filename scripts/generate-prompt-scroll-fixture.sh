#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NEWMUX="$ROOT/bin/newmux"
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-scroll-test}
TARGET=${1:-newmux-scroll:main}
PROMPTS=${PROMPTS:-100}
DOC_LINES=${DOC_LINES:-500}
DOC_FILE="${TMPDIR:-/tmp}/newmux-scroll-doc-$$.txt"

cleanup()
{
	rm -f "$DOC_FILE"
}
trap cleanup EXIT INT TERM

make_doc()
{
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
	label=$1
	send_line "printf '\\n### NEWMUX_REGION_${label}_START ###\\n'"
}

send_wait()
{
	label=$1
	send_line "\"$NEWMUX\" -L \"$SOCKET_NAME\" wait-for -S scroll-fixture-${label}"
	"$NEWMUX" -L "$SOCKET_NAME" wait-for "scroll-fixture-${label}"
}

generate_region()
{
	label=$1
	kind=$2
	count=$3

	send_marker "$label"
	i=1
	while [ "$i" -le "$count" ]; do
		case "$kind" in
		blank)
			"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$PANE" C-m
			;;
		true)
			send_line true
			;;
		ls)
			send_line ls
			;;
		tiny)
			send_line "printf 'tiny-output-%03d\\n' $i"
			;;
		esac
		i=$((i + 1))
	done
}

make_doc
PANE=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p -t "$TARGET" '#{pane_id}')

sleep 0.3
send_marker REAL_SHELL
send_line "printf 'Using your normal shell prompt/config for this scroll fixture.\\n'"
send_wait setup

generate_region BLANK blank "$PROMPTS"
send_wait blank
generate_region TRUE true "$PROMPTS"
send_wait true
generate_region LS ls 20
send_wait ls
generate_region TINY tiny "$PROMPTS"
send_wait tiny
send_marker DOC
send_line "cat '$DOC_FILE'"
send_wait doc
send_marker END
send_line "printf '\\nNewmux prompt scroll fixture ready. Press Cmd+Shift+H, then scroll through BLANK, TRUE, LS, TINY, and DOC regions.\\n'"
send_wait ready
