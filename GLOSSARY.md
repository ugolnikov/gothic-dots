# Desktop dotfiles

A gothic-minimal Hyprland desktop: the configs, the scripts that switch its look, and the guards that keep them honest.

## Language

**Gothic**:
The fixed dark visual identity — near-black ground, bone text, a blood accent, sharp corners, no blur.
_Avoid_: dark theme, default theme

**Palette**:
The set of colours the desktop renders with, either written as a fixed variant or derived from a wallpaper.
_Avoid_: theme, colourscheme, skin

**Mode**:
Which palette is in force — `dark` (the fixed gothic palette), `light` (the fixed ivory variant), or `dynamic` (derived from the wallpaper). Exactly one at a time.
_Avoid_: theme, variant

**Target**:
A generated colour file that one consumer reads; the palette's only contract with the apps.
_Avoid_: output, artifact, colour file

**Marker**:
The single persisted value recording the current mode.
_Avoid_: flag, sentinel, state file

**Consumer**:
An application that reads a target and reloads to pick up the new colours.
_Avoid_: client, app, themeable app

**Toggle**:
A session switch whose state outlives a single action — DND, night light, caffeine, recording. A marker records it, `controls.sh` owns it, and the quick panel is only a view.
_Avoid_: switch, flag, mode

**Quick panel**:
The rofi menu bound to `SUPER + Shift + C` that shows every toggle and passes the chosen row to `controls.sh`.
_Avoid_: control center, dashboard

**OSD**:
A short-lived on-screen indicator for volume or brightness, shown when a hardware key changes either. It is a view: the value itself belongs to the audio or backlight stack.
_Avoid_: overlay, HUD, popup

**Power profile**:
One of the system-wide performance modes exposed by power-profiles-daemon — `saver`, `balanced` or `performance`. `power.sh` owns the choice.
_Avoid_: power mode, preset, governor

**Session**:
A saved window layout: per window its workspace, tiled/floating state, geometry and the argv to relaunch it. `session.sh` owns it; restore only moves and launches, never closes.
_Avoid_: layout, snapshot, workspace profile

**Keyboard memory**:
The last xkb layout used in a window class, restored when a window of that class gains focus. A class-to-layout table records it; `eventd.sh` applies it.
_Avoid_: per-window layout, layout memory, keyboard profile

**Hook**:
An executable script in `eventd.d/` that eventd runs for a Hyprland event, named after the event (`monitor-added.sh`, `fullscreen-on.sh`, …).
_Avoid_: callback, handler

**Scratchpad**:
A named special workspace that holds one application and is toggled from any workspace. Its name-to-command mapping is configuration; the workspace itself is the only state.
_Avoid_: dropdown, special workspace, scratch

**Preset**:
A named bundle of settings (palette, animations, toggles, bar, power) that is applied together; apply snapshots only the keys it changes and off replays them.
_Avoid_: profile, mode, scene

**Slot**:
A named window of the day (day, evening, night) that ambience applies once: palette, night light and DND are set at its start and left alone until the next boundary.
_Avoid_: period, phase, schedule entry

**Launcher**:
The dmenu in front of every provider — applications, files, windows, clipboard, SSH hosts, packages, calculator. Its hub also accepts `:verbs` and hands them to `gothic`.
_Avoid_: menu, search bar

**Capture**:
The screenshot pipeline: a region, window or full screen, followed by optional annotation or OCR. `screenshot.sh` owns the pipeline; the output is a file or the clipboard.
_Avoid_: screenshot tool, grabber, snip

**Wallpaper**:
The desktop background image, and the source a dynamic palette is derived from. Chosen independently of the mode.
_Avoid_: background, backdrop

**Monitor arrangement**:
A saved mapping of outputs to mode, position, scale and transform, applied when a monitor is connected. Distinct from a Preset, which bundles desktop settings.
_Avoid_: monitor profile, display profile, layout

**Link plan**:
The single list of what this repository links where; each link pairs a repo path with the home path it is symlinked to. The install, uninstall, doctor and coverage paths all read it, so adding or removing a link is one edit.
_Avoid_: link map, symlink list
