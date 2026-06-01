#!/bin/sh
set -eu

# tmux copies terminal grid text, so right prompts and wide terminal columns can
# become very long runs of spaces. Normalize those visual gaps before pbcopy.
NEWMUX_COPY_GAP_COLUMNS=${NEWMUX_COPY_GAP_COLUMNS:-12}
export NEWMUX_COPY_GAP_COLUMNS

perl -0pe '
	BEGIN {
		$gap = $ENV{"NEWMUX_COPY_GAP_COLUMNS"};
		$gap = 12 unless defined($gap) && $gap =~ /^[0-9]+$/ && $gap > 0;
	}
	s/\r\n?/\n/g;
	s/[ \t]+$//mg;
	s/[ \t]{$gap,}/\n/g;
	s/[ \t]+$//mg;
' |
if [ "${NEWMUX_COPY_TO_STDOUT:-0}" = 1 ]; then
	cat
else
	pbcopy
fi
