# Newmux

Newmux is an experimental Ghostty + tmux distribution focused on making terminal work fast, recoverable, and less fragile.

The goal is not just to ship another tmux config. The goal is to turn a tmux fork into a recoverable terminal workspace engine that integrates cleanly with Ghostty.

## Core Idea

Terminals should have a browser-like undo model:

```text
Close the wrong pane or window.
Press Command + Shift + T.
Get useful terminal state back.
```

If the process is still alive, Newmux should restore it live. If the process died or the machine rebooted, Newmux should restore the useful work context: scrollback, cwd, command metadata, layout, and recovery state.

## First Features

- Faster and more usable tmux-style scrolling.
- Better copy and paste behavior.
- Better pane and window keybindings.
- Soft delete for panes and windows.
- Restore latest deleted pane or window.
- Live pane/history capture experiments.
- Scroll-up behavior that keeps command input feeling anchored at the bottom.

## Architecture Direction

For now, Newmux is a tmux fork plus Ghostty development profile:

```text
Ghostty frontend
  -> launches Newmux automatically
  -> sends restore/history keybindings

Newmux tmux fork
  -> owns sessions, panes, windows, layouts
  -> experiments with live history and recovery
  -> exposes restore/replay commands over tmux commands/control mode
```

Long term, the project may grow a dedicated daemon or Ghostty integration, but the current repository starts with the tmux fork because it already owns the terminal session model.

## Build

```sh
./scripts/build-newmux.sh
```

## Test

```sh
./scripts/test-newmux.sh
./scripts/test-ghostty-config.sh
```

## Open In Ghostty

```sh
./scripts/open-newmux-ghostty.sh
```

See `AGENTS.md` for the full product vision and implementation notes.
