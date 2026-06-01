#!/usr/bin/env python3
import argparse
import statistics
import subprocess
import threading
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
        if bounds.get("Width", 0) < 600 or bounds.get("Height", 0) < 400:
            continue
        if owner not in ("Dock", "Window Server"):
            any_app.append((name, bounds))
        if owner_query and owner_query.lower() not in owner.lower():
            continue
        fallback.append((name, bounds))
        if title and title not in name:
            continue
        choices.append((name, bounds))
    if not choices:
        candidates = fallback or any_app
        if not candidates:
            raise SystemExit(f"window not found: {title}")
        candidates.sort(key=lambda item: -(item[1]["Width"] * item[1]["Height"]))
        name, bounds = candidates[0]
        print(f"  warning=title_not_found fallback_window={name!r}")
        return name, bounds
    choices.sort(key=lambda item: -(item[1]["Width"] * item[1]["Height"]))
    return choices[0]


def screenshot(region: str, path: Path):
    started = time.perf_counter()
    subprocess.run(
        ["screencapture", "-x", "-R", region, str(path)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return time.perf_counter() - started


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
    event = Quartz.CGEventCreateScrollWheelEvent(None, Quartz.kCGScrollEventUnitLine, 1, delta)
    Quartz.CGEventSetLocation(event, (x, y))
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, event)


def main():
    parser = argparse.ArgumentParser(description="Capture Ghostty screenshots during active wheel scrolling.")
    parser.add_argument("--title", default="Newmux Live Scroll Test")
    parser.add_argument("--owner", default="Ghostty")
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--duration", type=float, default=1.4)
    parser.add_argument("--sample-interval", type=float, default=0.045)
    parser.add_argument("--event-interval", type=float, default=0.018)
    parser.add_argument("--delta", type=int, default=-4)
    parser.add_argument("--x-ratio", type=float, default=0.50)
    parser.add_argument("--y-ratio", type=float, default=0.72)
    parser.add_argument("--backend", choices=("screencapture", "quartz"), default="quartz")
    parser.add_argument("--save", action="store_true", help="save sampled frames as PNG files")
    parser.add_argument("--crop", default="", help="CSS-pixel crop x,y,w,h relative to the window")
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for path in out_dir.glob("active-*.png"):
        path.unlink()

    name, bounds = find_window(args.title, args.owner)
    x, y = int(bounds["X"]), int(bounds["Y"])
    width, height = int(bounds["Width"]), int(bounds["Height"])
    region = f"{x},{y},{width},{height}"
    point = (x + int(width * args.x_ratio), y + int(height * args.y_ratio))
    capture_x, capture_y, capture_width, capture_height = x, y, width, height
    if args.crop:
        crop_values = [int(value) for value in args.crop.split(",")]
        if len(crop_values) != 4:
            raise SystemExit("--crop must be x,y,w,h")
        capture_x = x + crop_values[0]
        capture_y = y + crop_values[1]
        capture_width = crop_values[2]
        capture_height = crop_values[3]
    capture_region = f"{capture_x},{capture_y},{capture_width},{capture_height}"

    subprocess.run(
        ["osascript", "-e", f"tell application \"{args.owner}\" to activate"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    time.sleep(0.2)

    running = True
    samples = []
    sample_images = []
    capture_times = []
    sample_times = []

    def sampler():
        index = 1
        while running:
            path = out_dir / f"active-{index}.png"
            if args.backend == "quartz":
                image, elapsed = capture_quartz(
                    capture_x, capture_y, capture_width, capture_height
                )
                if args.save:
                    image.save(path)
                samples.append(path)
                sample_images.append(image)
            else:
                elapsed = screenshot(capture_region, path)
                samples.append(path)
            capture_times.append(elapsed)
            sample_times.append(time.perf_counter())
            index += 1
            time.sleep(args.sample_interval)

    thread = threading.Thread(target=sampler)
    thread.start()
    started = time.perf_counter()
    event_count = 0
    while time.perf_counter() - started < args.duration:
        post_scroll(point[0], point[1], args.delta)
        event_count += 1
        time.sleep(args.event_interval)
    running = False
    thread.join()
    ended = time.perf_counter()
    elapsed = ended - started

    print("newmux active scroll UI probe")
    print(f"  window={name!r}")
    print(f"  region={region}")
    print(f"  capture_region={capture_region} backend={args.backend} save={args.save}")
    print(f"  point={point[0]},{point[1]} delta={args.delta}")
    print(f"  samples={len(samples)} output={out_dir}")
    print(f"  duration={elapsed:.3f}s scroll_events={event_count} event_rate={event_count / elapsed:.1f}/s")
    if sample_times:
        sample_elapsed = max(sample_times[-1] - sample_times[0], 0.000001)
        print(f"  sample_rate={len(sample_times) / sample_elapsed:.1f}/s")
    if capture_times:
        ordered = sorted(capture_times)
        p95 = ordered[min(len(ordered) - 1, int(len(ordered) * 0.95))]
        print(
            "  capture_ms="
            f"avg={statistics.fmean(capture_times) * 1000:.2f} "
            f"min={min(capture_times) * 1000:.2f} "
            f"p95={p95 * 1000:.2f} "
            f"max={max(capture_times) * 1000:.2f}"
        )

    previous = None
    previous_name = ""
    total = 0
    union = None
    changed_frames = 0
    quiet_frames = 0
    changed_values = []
    for index, path in enumerate(samples):
        if args.backend == "quartz":
            image = sample_images[index]
        else:
            image = Image.open(path).convert("RGB")
        if previous is not None:
            diff = ImageChops.difference(previous, image)
            bbox = diff.getbbox()
            changed = 0
            if bbox is not None:
                changed = sum(1 for pixel in diff.getdata() if pixel != (0, 0, 0))
                changed_frames += 1
                union = bbox if union is None else (
                    min(union[0], bbox[0]),
                    min(union[1], bbox[1]),
                    max(union[2], bbox[2]),
                    max(union[3], bbox[3]),
                )
            else:
                quiet_frames += 1
            changed_values.append(changed)
            total += changed
            print(f"  {previous_name}->{path.name}: changed={changed} bbox={bbox}")
        previous = image
        previous_name = path.name
    if len(samples) > 1:
        comparison_count = len(samples) - 1
        sample_elapsed = max(sample_times[-1] - sample_times[0], 0.000001) if sample_times else elapsed
        avg_changed = statistics.fmean(changed_values) if changed_values else 0
        max_changed = max(changed_values) if changed_values else 0
        print(
            "  visual_rate="
            f"changed_frames={changed_frames}/{comparison_count} "
            f"changed_fps={changed_frames / sample_elapsed:.1f} "
            f"quiet_frames={quiet_frames} "
            f"avg_changed_pixels={avg_changed:.0f} "
            f"max_changed_pixels={max_changed}"
        )
    print(f"  union={union} total_changed_pixels={total}")


if __name__ == "__main__":
    main()
