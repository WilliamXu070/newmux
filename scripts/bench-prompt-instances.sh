#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NEWMUX="$ROOT/bin/newmux"
CONF="$ROOT/config/newmux-dev.tmux.conf"
SOCKET_NAME="newmux-prompt-bench-$$"
LOG_FILE="${TMPDIR:-/tmp}/newmux-prompt-bench-$$.log"
DOC_FILE="${TMPDIR:-/tmp}/newmux-prompt-doc-$$.txt"
CAPTURE_FILE="${TMPDIR:-/tmp}/newmux-prompt-capture-$$.txt"
PROMPTS=${PROMPTS:-100}
DOC_LINES=${DOC_LINES:-500}
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
	if [ -z "${NEWMUX_KEEP_BENCH_FILES:-}" ]; then
		rm -f "$LOG_FILE" "$DOC_FILE" "$CAPTURE_FILE"
	fi
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
	send_line "\"$NEWMUX\" -L \"$SOCKET_NAME\" wait-for -S prompt-bench-${label}"
	"$NEWMUX" -L "$SOCKET_NAME" wait-for "prompt-bench-${label}"
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
		tiny)
			send_line "printf 'tiny-output-%03d\\n' $i"
			;;
		esac
		i=$((i + 1))
	done
}

capture_history()
{
	"$NEWMUX" -L "$SOCKET_NAME" capture-pane -p -S -1000000 -t "$PANE" \
		>"$CAPTURE_FILE"
}

marker_line()
{
	label=$1
	perl -Mstrict -Mwarnings -e '
		my ($file, $label) = @ARGV;
		my $marker = "### NEWMUX_REGION_${label}_START ###";
		open my $fh, "<", $file or die "$file: $!";
		my $line = 0;
		while (defined(my $text = <$fh>)) {
			chomp $text;
			$text =~ s/[[:space:]]+\z//;
			if ($text eq $marker) {
				print "$line\n";
				exit 0;
			}
			$line++;
		}
		die "marker not found: $marker\n";
	' "$CAPTURE_FILE" "$label"
}

bench_region()
{
	name=$1
	start=$2
	end=$3

	if [ "$start" -lt "$end" ]; then
		lines=$((end - start))
	else
		lines=$((start - end))
	fi
	if [ "$lines" -lt 1 ]; then
		lines=1
	fi

	"$NEWMUX" -L "$SOCKET_NAME" copy-mode "$COPY_FLAGS" -t "$PANE"
	"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$PANE" -X history-top
	if [ "$end" -gt 0 ]; then
		"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$PANE" -N "$end" \
			-X scroll-down
	fi
	up_ms=$(elapsed_ms "$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$PANE" \
		-N "$lines" -X scroll-up)

	"$NEWMUX" -L "$SOCKET_NAME" copy-mode "$COPY_FLAGS" -t "$PANE"
	"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$PANE" -X history-top
	if [ "$start" -gt 0 ]; then
		"$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$PANE" -N "$start" \
			-X scroll-down
	fi
	down_ms=$(elapsed_ms "$NEWMUX" -L "$SOCKET_NAME" send-keys -t "$PANE" \
		-N "$lines" -X scroll-down)

	perl -e '
		my ($name, $lines, $up, $down) = @ARGV;
		printf "%-12s lines=%4d up=%8.3f ms (%8.1f lines/s) down=%8.3f ms (%8.1f lines/s)\n",
		    $name, $lines, $up, $lines / ($up / 1000), $down,
		    $lines / ($down / 1000);
	' "$name" "$lines" "$up_ms" "$down_ms"
}

make_doc
"$NEWMUX" -L "$SOCKET_NAME" -f "$CONF" new-session -d -x "$WIDTH" -y "$HEIGHT" \
	-s prompt-bench -n main "zsh -df"
PANE=$("$NEWMUX" -L "$SOCKET_NAME" display-message -p -t prompt-bench:main '#{pane_id}')

sleep 0.5

send_line 'unsetopt zle prompt_cr prompt_sp; PROMPT="prompt-%! > "; RPROMPT=""; export PS1="$PROMPT"'
send_line 'PROMPT_N=0; precmd() { PROMPT_N=$((PROMPT_N + 1)); PROMPT="prompt-${PROMPT_N} > "; }'
send_wait setup
generate_region BLANK blank "$PROMPTS"
send_wait blank
generate_region TRUE true "$PROMPTS"
send_wait true
generate_region TINY tiny "$PROMPTS"
send_wait tiny
send_marker DOC
send_line "cat '$DOC_FILE'"
send_wait doc
send_marker END
send_wait ready

capture_history

script -q "$LOG_FILE" "$NEWMUX" -L "$SOCKET_NAME" attach-session -t prompt-bench >/dev/null 2>&1 &
SCRIPT_PID=$!
sleep 0.2

blank_pos=$(marker_line BLANK)
true_pos=$(marker_line TRUE)
tiny_pos=$(marker_line TINY)
doc_pos=$(marker_line DOC)
end_pos=$(marker_line END)

echo "newmux prompt-instance benchmark"
echo "  prompts=$PROMPTS doc_lines=$DOC_LINES size=${WIDTH}x${HEIGHT} copy_flags=$COPY_FLAGS"
bench_region BLANK "$blank_pos" "$true_pos"
bench_region TRUE "$true_pos" "$tiny_pos"
bench_region TINY "$tiny_pos" "$doc_pos"
bench_region DOC "$doc_pos" "$end_pos"
