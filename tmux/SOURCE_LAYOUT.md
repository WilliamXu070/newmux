# Source Layout

This fork keeps upstream tmux behavior intact, but the formerly flat source
tree is organized by responsibility so agents can find change points faster.

## Folders

- `commands/`: tmux command implementations, including command parsing.
- `core/`: process entrypoint, config loading, logging, jobs, allocation, and small shared utilities.
- `options/`: environment and option table/state handling.
- `screen/`: screen/grid model, format drawing, and screen-write operations.
- `server/`: client/server process coordination, control mode, IPC, and server lifecycle.
- `terminal/`: terminal I/O, input parsing, key handling, tty features, styles, colors, UTF-8, hyperlinks, and images.
- `ui/`: interactive tmux UI surfaces such as menus, popups, mode tree, paste buffers, and status line.
- `windows/`: sessions, windows, panes, layouts, spawning, resizing, alerts, and window-specific modes.
- `platform/`: OS-dependent implementations selected by configure.
- `compat/`: compatibility shims from upstream tmux.
- `fuzz/`: upstream fuzzing targets.

## Shared Headers

The main shared headers remain at the source root:

- `tmux.h`
- `tmux-protocol.h`
- `compat.h`
- `xmalloc.h`

Keeping these headers at the root avoids touching include directives across
the fork. The build keeps `-iquote .`, so sources in subfolders still resolve
the shared headers.

## Newmux Work Areas

For live visual history, likely first files to inspect are:

- `terminal/input.c`
- `screen/screen-write.c`
- `screen/grid.c`
- `windows/window-copy.c`
- `windows/window.c`
- `server/server-client.c`

The current live-history prototype is implemented as `copy-mode -L`:

- `commands/cmd-copy-mode.c` parses the flag.
- `windows/window-copy.c` aliases copy-mode backing to the live pane screen and updates/redraws the viewport.
- `windows/window.c` calls the copy-mode update hook after pane input is parsed.

For soft-close or restore behavior, likely first files to inspect are:

- `commands/cmd-kill-pane.c`
- `commands/cmd-kill-window.c`
- `commands/cmd-kill-session.c`
- `windows/window.c`
- `windows/session.c`
- `server/server-fn.c`
