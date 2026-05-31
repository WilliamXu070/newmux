#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT_DIR="$ROOT/.local/live-scroll-test/latest/ui-probe"
WINDOW_TITLE=${WINDOW_TITLE:-Newmux Live Scroll Test}
SAMPLES=${SAMPLES:-8}
INTERVAL=${INTERVAL:-0.15}
MIN_CHANGED_PIXELS=${MIN_CHANGED_PIXELS:-25}
NEWMUX="$ROOT/bin/newmux"
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-live-scroll-test}
TARGET=${TARGET:-newmux-live-scroll:main}

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/sample-*.png "$OUT_DIR"/diff-*.png "$OUT_DIR"/bounds.txt \
	"$OUT_DIR"/mode-before.txt "$OUT_DIR"/mode-after.txt

"$NEWMUX" -L "$SOCKET_NAME" capture-pane -pM -t "$TARGET" \
	>"$OUT_DIR/mode-before.txt" 2>/dev/null || true

bounds=$(osascript <<APPLESCRIPT
tell application "System Events"
	repeat with proc in processes whose name is "ghostty"
		set frontmost of proc to true
		repeat with w in windows of proc
			if name of w is "$WINDOW_TITLE" then
				perform action "AXRaise" of w
				set winpos to position of w
				set winsize to size of w
				return (item 1 of winpos as text) & "," & (item 2 of winpos as text) & "," & (item 1 of winsize as text) & "," & (item 2 of winsize as text)
			end if
		end repeat
	end repeat
end tell
APPLESCRIPT
)

if [ -z "$bounds" ]; then
	echo "Ghostty window not found: $WINDOW_TITLE" >&2
	exit 1
fi

echo "$bounds" > "$OUT_DIR/bounds.txt"

i=1
while [ "$i" -le "$SAMPLES" ]; do
	screencapture -x -R "$bounds" "$OUT_DIR/sample-$i.png"
	sleep "$INTERVAL"
	i=$((i + 1))
done

"$NEWMUX" -L "$SOCKET_NAME" capture-pane -pM -t "$TARGET" \
	>"$OUT_DIR/mode-after.txt" 2>/dev/null || true

python3 - "$OUT_DIR" "$SAMPLES" "$MIN_CHANGED_PIXELS" <<'PY'
import sys
from pathlib import Path
from PIL import Image, ImageChops

out_dir = Path(sys.argv[1])
samples = int(sys.argv[2])
threshold = int(sys.argv[3])

def content_crop(im):
    w, h = im.size
    # Ignore the titlebar and tmux status bar. This is the actual headed UI,
    # and the staged animation sits in the lower terminal body.
    left = 0
    top = int(h * 0.42)
    right = w
    bottom = int(h * 0.94)
    return im.crop((left, top, right, bottom))

changes = []
total_changed = 0
for i in range(1, samples):
    a = content_crop(Image.open(out_dir / f"sample-{i}.png").convert("RGB"))
    b = content_crop(Image.open(out_dir / f"sample-{i + 1}.png").convert("RGB"))
    diff = ImageChops.difference(a, b)
    bbox = diff.getbbox()
    changed = 0
    if bbox is not None:
        changed = sum(1 for px in diff.getdata() if px != (0, 0, 0))
        diff.save(out_dir / f"diff-{i}-{i + 1}.png")
    total_changed += changed
    changes.append((i, i + 1, changed, bbox))

print("newmux headed UI pixel probe")
print(f"  samples={samples} threshold={threshold}")
print(f"  output={out_dir}")
print("  method=screenshot_interval_pixel_diff")
for a, b, changed, bbox in changes:
    print(f"  sample {a}->{b}: changed_pixels={changed} bbox={bbox}")

strong_changes = [changed for _, _, changed, _ in changes if changed >= threshold]
if len(strong_changes) >= 2:
    print(f"  changed_pairs={len(strong_changes)} total_changed_pixels={total_changed}")
    print("  result=PASS_VISUAL_ANIMATION_CHANGED")
    sys.exit(0)

print(f"  changed_pairs={len(strong_changes)} total_changed_pixels={total_changed}")
print("  result=FAIL_VISUAL_ANIMATION_STATIC")
sys.exit(2)
PY
