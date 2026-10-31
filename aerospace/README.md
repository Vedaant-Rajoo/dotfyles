# AeroSpace

Homebrew owns AeroSpace through `Brewfile`. The live configuration is
`~/.config/aerospace/aerospace.toml`; do not also create `~/.aerospace.toml`,
because AeroSpace reports an error when both exist.

`start-at-login = true` uses AeroSpace's native macOS login registration.
`auto-reload-config = true` applies saved configuration changes automatically.
No Homebrew service or separate watcher is needed.

## Setup

```bash
brew install --cask nikitabobko/tap/aerospace
open -a AeroSpace
```

Grant AeroSpace access in **System Settings > Privacy & Security > Accessibility**.
Select `/Applications/AeroSpace.app` if adding it manually. Keep Rectangle Pro
quit and its launch-at-login setting disabled. Its app and exported settings
remain available as a fallback.

## Keyboard controls

Hold Ctrl+Cmd for the following shortcuts. This leaves Herdr's Ctrl+Alt
shortcuts and Karabiner's Caps Lock hyper arrows available.

- H/J/K/L: focus left/down/up/right; add Shift to move the window.
- 1–4: switch to Main, Code, Web, or Chat; add Shift to send the window there.
- Left/Right: previous/next workspace. Tab: previous active workspace.
- R: enter resize mode. Release modifiers, then H/L shrink/grow width and
  K/J shrink/grow height. Escape or Enter returns to the main mode.
- F: toggle fullscreen. Shift+Space: toggle floating.
- Slash: toggle tile orientation. Comma: switch to accordion layout and toggle
  its orientation. Equal: balance split sizes.
- Z: pause/resume AeroSpace. This applies to the whole window manager.

The menu bar shows the active workspace and binding mode. Directional focus
and split resizing need more than one tiled window in the same workspace.

Ghostty, Cursor, and T3 Code route to Code; Search routes to Web; Legcord routes
to Chat. Other apps use the active workspace. AeroSpace automatically floats
dialogs using its built-in heuristics. No app exclusions or forced sizes are set.

Workspaces are shared across monitors and are separate from macOS Spaces.
Create another workspace with `aerospace workspace NAME`; empty workspaces
disappear unless listed in `persistent-workspaces`.

## Checks

```bash
aerospace reload-config --dry-run --no-gui --warnings-as-errors
aerospace list-workspaces --all
aerospace list-windows --all
aerospace list-modes --current
```

Use `aerospace reload-config` if an edit does not appear automatically.
Use `aerospace enable off` to pause window management before troubleshooting.

References: [official guide](https://nikitabobko.github.io/AeroSpace/guide) and
[command reference](https://nikitabobko.github.io/AeroSpace/commands).
