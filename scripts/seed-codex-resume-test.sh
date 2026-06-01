#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NEWMUX="$ROOT/bin/newmux"
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-codex-resume-test}
TARGET=${1:-newmux-codex-resume:main}
START_DELAY=${CODEX_RESUME_START_DELAY:-1.2}
RESUME_DELAY=${CODEX_RESUME_DELAY:-2.5}
RESUME_ENTER_DELAY=${CODEX_RESUME_ENTER_DELAY:-0.8}
RESUME_SELECT_DELAY=${CODEX_RESUME_SELECT_DELAY:-0.8}
TIMEOUT_SECONDS=${CODEX_RESUME_TIMEOUT_SECONDS:-45}

send_line()
{
	"$NEWMUX" -L "$SOCKET_NAME" send-keys -l -t "$PANE" "$1"
	"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$PANE" C-m
}

send_text()
{
	"$NEWMUX" -L "$SOCKET_NAME" send-keys -l -t "$PANE" "$1"
}

send_enter()
{
	"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$PANE" Enter
}

wait_for_text()
{
	pattern=$1
	label=$2
	i=0
	limit=$((TIMEOUT_SECONDS * 2))
	while [ "$i" -lt "$limit" ]; do
		if "$NEWMUX" -L "$SOCKET_NAME" capture-pane -p -t "$TARGET" \
		    2>/dev/null | grep -Eq "$pattern"; then
			return
		fi
		sleep 0.5
		i=$((i + 1))
	done
	echo "timed out waiting for $label" >&2
	exit 1
}

wait_for_shell()
{
	i=1
	while [ "$i" -le 80 ]; do
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

wait_for_shell
PANE=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p -t "$TARGET" '#{pane_id}')

sleep "$START_DELAY"
send_line "printf '\\n### NEWMUX_CODEX_RESUME_TEST ###\\n'"
send_line "printf 'Launching Codex, sending /resume, then leaving the headed UI for physical scroll testing.\\n'"
send_line "codex"
sleep "$RESUME_DELAY"
wait_for_text 'OpenAI Codex|model:|directory:' 'Codex main screen'
send_text "/resume"
sleep "$RESUME_ENTER_DELAY"
send_enter
wait_for_text 'Resume a previous session|Type to search|Filter:|Sort:' 'Codex resume picker'
sleep "$RESUME_SELECT_DELAY"
send_enter
wait_for_text 'gpt-.*·|› |• |Conversation interrupted|OpenAI Codex|Token usage|To continue this session' 'resumed Codex session'
"$NEWMUX" -L "$SOCKET_NAME" wait-for -S codex-resume-seeded
