#!/usr/bin/env perl
use strict;
use warnings;
use Time::HiRes qw(usleep);

$| = 1;

my @frames = ('|', '/', '-', '\\');
my @colours = (196, 46, 21, 226, 201, 51);
my $i = 0;
my $rows_below = 8;
my $block_rows = 6;
my $move_rows = $rows_below + $block_rows;
my $lines = $ENV{LINES} || 24;
my $prime_rows = $lines > 16 ? $lines - 14 : 8;

print "\nNEWMUX_ANIMATION_START\n";
print "Priming viewport so the animation block sits at the pane bottom.\n";
for my $row (1 .. $prime_rows) {
	printf "NEWMUX_ANIM_PRIME_%02d\n", $row;
}
print "Scroll up 2-3 lines. The highest padding rows should remain visible, bottom padding rows should disappear.\n";
print "NEWMUX_ANIM frame=000000 |  live-history-visible-test\n";
for my $row (1 .. $block_rows - 1) {
	printf "NEWMUX_ANIM_DETAIL_%02d codex-style-live-block\n", $row;
}
for my $row (1 .. $rows_below) {
	printf "NEWMUX_ANIM_PADDING_%02d below-animation-line\n", $row;
}

while (1) {
	my $frame = $frames[$i % @frames];
	my $colour = $colours[$i % @colours];
	printf "\033[%dA", $move_rows;
	printf "\r\033[KNEWMUX_ANIM frame=%06d %s  live-history-visible-test  \033[48;5;%dm        \033[0m\n",
	    $i, $frame, $colour;
	for my $row (1 .. $block_rows - 1) {
		printf "\r\033[KNEWMUX_ANIM_DETAIL_%02d repaint=%06d codex-style-live-block\n",
		    $row, $i;
	}
	printf "\033[%dB", $rows_below;
	usleep(80_000);
	$i++;
}
