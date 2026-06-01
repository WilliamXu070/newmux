# Live Scroll Baseline: 2026-05-31

This note records the performance comparison against the pre-live-history tmux fork from this morning.

## Baseline Compared

- Old baseline commit: `be9cb9d` (`Use stable Ghostty by default`)
- Old worktree: `/Users/williamxu/Desktop/Projects/newmux-baseline-be9cb9d`
- Current branch: `main`
- Current latest committed change before this note: `82a9985` (`Fix live selection cursor suppression`)
- Current working tree also contains uncommitted live-scroll optimization changes in `tmux/windows/window-copy.c`

The old baseline is the state immediately before `59907ce` (`v1 live history copy mode`).

## Measurement

This measures tmux/server-side copy-mode scroll command cost, not full physical trackpad FPS in Ghostty.

Fixture:

- Pane size: `215x60`
- History size: `6341` lines
- Scroll operation: 500 individual one-line `scroll-up` commands sent through one tmux control-mode client
- Passes: 7
- Content: repeated prompt-like output with powerline glyphs and long `ls`-style lines

## Results

| Case | Mode | Average per one-line scroll | Notes |
| --- | --- | ---: | --- |
| Old baseline | regular copy-mode | `0.674 ms` | pre-live-history tmux fork |
| Current | regular copy-mode | `0.653 ms` | roughly same as old baseline |
| Current | live copy-mode `-LH` | `0.112 ms` | about `6.0x` faster than old baseline on this tmux-side benchmark |

Raw passes:

```text
old baseline regular copy-mode:
0.676, 0.657, 0.660, 0.674, 0.679, 0.704, 0.668 ms/scroll

current regular copy-mode:
0.666, 0.652, 0.645, 0.654, 0.650, 0.651, 0.652 ms/scroll

current live copy-mode:
0.117, 0.111, 0.109, 0.111, 0.107, 0.112, 0.114 ms/scroll
```

## Interpretation

The current live-mode scroll command path is not slower than the old pre-live tmux path in this isolated tmux-side measurement. It is faster because the live path now uses batched scroll movement and narrower redraw work.

If the terminal still feels slower than the old non-live version during real Ghostty use, the remaining slowdown is likely outside this narrow benchmark:

- physical wheel/trackpad event rate and smoothing behavior
- Ghostty redraw/compositing cost
- cursor and selection invalidation while events are actively arriving
- live animation refresh work overlapping scroll redraws
- full-pane redraw fallbacks when overlays, selections, or mode transitions force them

So the next meaningful benchmark should measure active UI frames/screenshots during real scroll input, not only tmux command execution time.

## Visible UI Metrics

After adding timing to `scripts/probe-active-scroll-ui.py`, active Ghostty scroll was measured with real Quartz wheel events while sampling the visible window.

Important caveat: screenshot sampling itself has overhead, so these numbers are a lower bound on visible FPS. Full-window capture is especially expensive on the Retina display.

Full-window capture:

- Capture region: full Ghostty window, `1728x1084` CSS pixels (`3456x2168` physical pixels)
- Average capture cost: about `116.8 ms`
- Effective sample rate: about `8 FPS`

Focused content capture:

- Capture region: terminal content crop, `1728x850` CSS pixels
- Average capture cost: about `33-34 ms`
- Effective sample rate: about `31-32 FPS`

Sustained normal-speed scroll, current live copy-mode:

```text
duration=1.409s
scroll_events=31
event_rate=22.0/s
sample_rate=30.7/s
changed_frames=30/40
changed_fps=22.4
scroll_position: 120 -> 346
```

Sustained normal-speed scroll, current regular copy-mode:

```text
duration=1.450s
scroll_events=32
event_rate=22.1/s
sample_rate=30.8/s
changed_frames=31/42
changed_fps=22.2
scroll_position: 120 -> 353
```

Fast scroll, current live copy-mode:

```text
duration=1.013s
scroll_events=51
event_rate=50.4/s
sample_rate=32.0/s
changed_frames=29/29
changed_fps=31.0
scroll_position: 120 -> 496
```

Selection-active scroll, current live copy-mode:

```text
duration=1.411s
scroll_events=31
event_rate=22.0/s
sample_rate=31.1/s
changed_frames=14/41
changed_fps=10.4
scroll_position: 100 -> 78
selection_present=1
selection_active=1
```

## Visible Interpretation

The visible UI test explains the user's reported lag better than the tmux command benchmark.

At normal input speed, live mode and regular copy-mode look almost identical: about `22 changed FPS`. At fast input speed, live mode can still visibly change around the sampler ceiling (`31 changed FPS`), but it moves too much text per visible frame:

```text
fast scroll displacement = 376 history lines / 29 changed frames
                         = about 13 lines per visible frame
```

That means the current problem is probably not raw tmux scroll-command cost. The user-visible problem is likely scroll coalescing and visual pacing:

- many wheel events are accepted per second
- each event can advance multiple lines
- Ghostty/tmux only presents a smaller number of visible frames
- the viewport therefore jumps many lines per visible frame

This matches the subjective feeling: the terminal is not necessarily "slow" in the server path, but it can feel laggy and unresponsive because fast scrolling turns into large visual jumps instead of smooth paced movement.

## Selection Finding

The user correctly identified another major fluidity issue: selection-active scrolling is much worse than plain scrolling.

Under the same visible test rate of about `22` scroll events per second:

- no selection, live copy-mode: about `22.4 changed FPS`
- regular copy-mode: about `22.2 changed FPS`
- selection active, live copy-mode: about `10.4 changed FPS`

This points at selection invalidation/repaint behavior rather than raw scroll-command cost. A tmux command-only benchmark with a keyboard selection active still measured about `0.147 ms` per scroll, similar to no-selection live scrolling. The visible slowdown appears when the selected/highlighted region has to be represented on screen.

Likely contributors in `tmux/windows/window-copy.c`:

- `window_copy_drag_update` calls `window_copy_redraw_screen` on native selection drag updates.
- `window_copy_start_drag` calls `window_copy_redraw_screen` when native live selection starts.
- `window_copy_scroll_up` and `window_copy_scroll_down` take extra redraw branches when `s->sel != NULL`.
- `window_copy_set_selection` recomputes and reapplies screen selection on scroll.

The next selection-specific optimization should preserve the selected grid anchors but redraw only the rows where the selection enters, exits, or changes, instead of treating selection as a reason to invalidate large parts of the visible screen.

## macOS Terminal.app Zsh Comparison

A plain macOS Terminal.app zsh window was tested with the same visible Quartz screenshot probe.

Fixture:

- App: Terminal.app
- Shell: plain `zsh -f`
- Window size: `213x55` terminal cells, `1728x1084` CSS pixels
- Capture crop: `1728x850` CSS pixels
- Content: 4000 repeated zsh output lines

Normal-speed scroll:

```text
duration=1.459s
scroll_events=32
event_rate=21.9/s
sample_rate=32.0/s
changed_frames=31/44
changed_fps=22.0
```

Fast scroll:

```text
duration=1.028s
scroll_events=51
event_rate=49.6/s
sample_rate=31.9/s
changed_frames=26/30
changed_fps=26.8
```

Interpretation:

- Terminal.app is not showing up as a clean `60 FPS` target with this probe; the screenshot sampler itself tops out near `32 FPS` on the large Retina capture.
- At normal input rate, Terminal.app and newmux live mode both visibly update around `22 FPS`.
- At fast input rate, Terminal.app measures around `27 FPS`; newmux live mode measured around `31 FPS` in a similar large-window crop.
- The major measured regression remains selection-active newmux scrolling, which dropped to about `10.4 FPS`.

So the strongest validated problem is not "newmux is always slower than Terminal." It is "newmux selection/highlight state tanks visible update cadence."

## Scroll Latency Redo

Latency is a better metric for perceived fluidity than FPS alone. A new probe, `scripts/probe-scroll-latency-ui.py`, measures:

1. capture the current screen crop
2. post one Quartz scroll wheel event
3. repeatedly capture the crop until pixels change
4. report input-to-first-visible-change latency

The test alternates scroll direction so the viewport shakes up/down instead of running into history boundaries.

Fixture:

- Events: `24`
- Delta: `1`
- Direction: alternating up/down
- Threshold: `800` changed pixels
- Capture crop: `1728x260` CSS pixels
- Output logs: `.local/scroll-latency/latest-redo/`

Results:

| Case | Avg Latency | P50 | P95 | Max | Notes |
| --- | ---: | ---: | ---: | ---: | --- |
| Terminal.app zsh | `20.54 ms` | `18.93 ms` | `22.58 ms` | `53.87 ms` | plain zsh scrollback |
| newmux live, no selection | `36.66 ms` | `38.60 ms` | `49.99 ms` | `54.00 ms` | live copy-mode, no selection |
| newmux live, selection active | `53.25 ms` | `47.41 ms` | `72.82 ms` | `118.77 ms` | live copy-mode with active selection |

Interpretation:

- This latency test validates the user's feeling better than the FPS test.
- Terminal.app responds in roughly one capture/sample interval, around `19-21 ms` most of the time.
- Newmux live without selection is about `1.8x` slower on average than Terminal.app in this latency probe.
- Newmux live with active selection is about `2.6x` slower on average than Terminal.app and has much worse spikes.

The current highest-value optimization target is therefore input-to-visible-change latency, especially when selection is present. Selection should not force enough redraw/invalidation work to push response into the `50-120 ms` range.
