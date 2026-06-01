#!/usr/bin/env python3
import argparse
import statistics
import subprocess
import time
from pathlib import Path

import Quartz
from PIL import Image, ImageChops


def find_window(title: str, owner_query: str):
    windows = Quartz.CGWindowListCopyWindowInfo(
        Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID
    )
    choices = []
    fallback = []
    any_app = []
    for window in windows:
        owner = window.get("kCGWindowOwnerName", "")
        name = window.get("kCGWindowName", "")
        bounds = window.get("kCGWindowBounds", {})
        if bounds.get("Width", 0) < 300 or bounds.get("Height", 0) < 200:
            continue
        if owner not in ("Dock", "Window Server"):
            any_app.append((owner, name, bounds))
        if owner_query and owner_query.lower() not in owner.lower():
            continue
        fallback.append((owner, name, bounds))
        if title and title not in name:
            continue
        choices.append((owner, name, bounds))
    if not choices:
        if owner_query and not fallback:
            raise SystemExit(f"window owner not found: {owner_query} {title}")
        candidates = fallback or any_app
        if not candidates:
            raise SystemExit(f"window not found: {owner_query} {title}")
        candidates.sort(key=lambda item: -(item[2]["Width"] * item[2]["Height"]))
        owner, name, bounds = candidates[0]
        print(f"  warning=title_not_found fallback_owner={owner!r} fallback_window={name!r}")
        return owner, name, bounds
    choices.sort(key=lambda item: -(item[2]["Width"] * item[2]["Height"]))
    return choices[0]


def capture_quartz(x: int, y: int, width: int, height: int):
    started = time.perf_counter()
    rect = Quartz.CGRectMake(x, y, width, height)
    image = Quartz.CGWindowListCreateImage(
        rect,
        Quartz.kCGWindowListOptionOnScreenOnly,
        Quartz.kCGNullWindowID,
        Quartz.kCGWindowImageDefault,
    )
    if image is None:
        raise RuntimeError("Quartz capture failed")
    data = Quartz.CGDataProviderCopyData(Quartz.CGImageGetDataProvider(image))
    size = (Quartz.CGImageGetWidth(image), Quartz.CGImageGetHeight(image))
    stride = Quartz.CGImageGetBytesPerRow(image)
    pil = Image.frombuffer("RGBA", size, bytes(data), "raw", "BGRA", stride, 1)
    return pil.convert("RGB"), time.perf_counter() - started


def post_scroll(x: int, y: int, delta: int):
    event = Quartz.CGEventCreateScrollWheelEvent(
        None, Quartz.kCGScrollEventUnitLine, 1, delta
    )
    Quartz.CGEventSetLocation(event, (x, y))
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, event)


def changed_pixels(before: Image.Image, after: Image.Image, threshold: int):
    diff = ImageChops.difference(before, after)
    bbox = diff.getbbox()
    if bbox is None:
        return 0, None
    changed = 0
    for pixel in diff.getdata():
        if pixel != (0, 0, 0):
            changed += 1
            if changed >= threshold:
                return changed, bbox
    return changed, bbox


def main():
    parser = argparse.ArgumentParser(
        description="Measure scroll input to first visible change latency."
    )
    parser.add_argument("--owner", default="Ghostty")
    parser.add_argument("--title", default="Newmux Codex Resume Scroll Test")
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--events", type=int, default=24)
    parser.add_argument("--timeout", type=float, default=0.250)
    parser.add_argument("--rest", type=float, default=0.045)
    parser.add_argument("--delta", type=int, default=1)
    parser.add_argument("--alternate", action="store_true")
    parser.add_argument("--threshold", type=int, default=1200)
    parser.add_argument("--x-ratio", type=float, default=0.50)
    parser.add_argument("--y-ratio", type=float, default=0.72)
    parser.add_argument("--crop", default="", help="CSS-pixel crop x,y,w,h relative to the window")
    parser.add_argument("--save-samples", action="store_true")
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    if args.save_samples:
        for path in out_dir.glob("latency-*.png"):
            path.unlink()

    owner, name, bounds = find_window(args.title, args.owner)
    x, y = int(bounds["X"]), int(bounds["Y"])
    width, height = int(bounds["Width"]), int(bounds["Height"])
    capture_x, capture_y, capture_width, capture_height = x, y, width, height
    if args.crop:
        crop_values = [int(value) for value in args.crop.split(",")]
        if len(crop_values) != 4:
            raise SystemExit("--crop must be x,y,w,h")
        capture_x = x + crop_values[0]
        capture_y = y + crop_values[1]
        capture_width = crop_values[2]
        capture_height = crop_values[3]

    point = (x + int(width * args.x_ratio), y + int(height * args.y_ratio))
    subprocess.run(
        ["osascript", "-e", f"tell application \"{args.owner}\" to activate"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    time.sleep(0.2)

    latencies = []
    misses = 0
    capture_costs = []
    sample_counts = []
    changed_counts = []

    print("newmux scroll latency UI probe")
    print(f"  owner={owner!r} window={name!r}")
    print(f"  window_region={x},{y},{width},{height}")
    print(f"  capture_region={capture_x},{capture_y},{capture_width},{capture_height}")
    print(
        f"  point={point[0]},{point[1]} events={args.events} "
        f"delta={args.delta} alternate={args.alternate} threshold={args.threshold}"
    )

    before, cost = capture_quartz(capture_x, capture_y, capture_width, capture_height)
    capture_costs.append(cost)
    for index in range(1, args.events + 1):
        delta = args.delta
        if args.alternate and index % 2 == 0:
            delta = -delta

        posted = time.perf_counter()
        post_scroll(point[0], point[1], delta)
        samples = 0
        hit_latency = None
        hit_changed = 0
        hit_bbox = None

        while time.perf_counter() - posted < args.timeout:
            current, cost = capture_quartz(
                capture_x, capture_y, capture_width, capture_height
            )
            sampled_at = time.perf_counter()
            capture_costs.append(cost)
            samples += 1
            changed, bbox = changed_pixels(before, current, args.threshold)
            if changed >= args.threshold:
                hit_latency = sampled_at - posted
                hit_changed = changed
                hit_bbox = bbox
                before = current
                if args.save_samples:
                    current.save(out_dir / f"latency-{index:03d}.png")
                break

        if hit_latency is None:
            misses += 1
            before, cost = capture_quartz(
                capture_x, capture_y, capture_width, capture_height
            )
            capture_costs.append(cost)
            print(f"  event={index:02d} delta={delta:+d} miss samples={samples}")
        else:
            latencies.append(hit_latency)
            sample_counts.append(samples)
            changed_counts.append(hit_changed)
            print(
                f"  event={index:02d} delta={delta:+d} "
                f"latency_ms={hit_latency * 1000:.2f} samples={samples} "
                f"changed>={hit_changed} bbox={hit_bbox}"
            )

        time.sleep(args.rest)

    if latencies:
        ordered = sorted(latencies)
        p50 = statistics.median(ordered)
        p95 = ordered[min(len(ordered) - 1, int(len(ordered) * 0.95))]
        p99 = ordered[min(len(ordered) - 1, int(len(ordered) * 0.99))]
        capture_ordered = sorted(capture_costs)
        capture_p95 = capture_ordered[
            min(len(capture_ordered) - 1, int(len(capture_ordered) * 0.95))
        ]
        print(
            "  latency_summary="
            f"hits={len(latencies)} misses={misses} "
            f"avg_ms={statistics.fmean(latencies) * 1000:.2f} "
            f"p50_ms={p50 * 1000:.2f} "
            f"p95_ms={p95 * 1000:.2f} "
            f"p99_ms={p99 * 1000:.2f} "
            f"min_ms={min(latencies) * 1000:.2f} "
            f"max_ms={max(latencies) * 1000:.2f}"
        )
        print(
            "  capture_summary="
            f"avg_ms={statistics.fmean(capture_costs) * 1000:.2f} "
            f"p95_ms={capture_p95 * 1000:.2f} "
            f"samples_per_hit_avg={statistics.fmean(sample_counts):.2f} "
            f"changed_pixels_avg={statistics.fmean(changed_counts):.0f}"
        )
    else:
        print(f"  latency_summary=hits=0 misses={misses}")


if __name__ == "__main__":
    main()
