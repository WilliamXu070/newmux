#!/bin/zsh
set -eu

printf '\033[2J\033[H'
printf 'Newmux scroll stress test\n'
printf 'Generated 1000 lines. Use the trackpad/wheel to test fast copy-mode scrolling.\n'
printf 'Press Cmd+Shift+H if you are not already in copy-mode, then scroll.\n'
printf '\n'

for i in {1..1000}; do
	printf '[%04d] newmux scroll sample | %s | payload: %s\n' \
		"$i" \
		"$(printf '%0.ssegment-' {1..6})" \
		"$(printf '%0.sabcdefghijklmnopqrstuvwxyz-' {1..3})"
done

printf '\n--- end of generated sample; shell is live below ---\n'
exec /bin/zsh -l
