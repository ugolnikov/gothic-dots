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

**Session**:
A saved window layout: per window its workspace, tiled/floating state, geometry and the argv to relaunch it. `session.sh` owns it; restore only moves and launches, never closes.
_Avoid_: layout, snapshot, workspace profile

**Wallpaper**:
The desktop background image, and the source a dynamic palette is derived from. Chosen independently of the mode.
_Avoid_: background, backdrop

**Link plan**:
The single list of what this repository links where; each link pairs a repo path with the home path it is symlinked to. The install, uninstall, doctor and coverage paths all read it, so adding or removing a link is one edit.
_Avoid_: link map, symlink list
