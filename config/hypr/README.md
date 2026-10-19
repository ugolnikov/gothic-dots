# Hyprland rice

A full Hyprland desktop: compositor, bar (Waybar), launcher (tofi), terminal
(**foot**), notifications (mako), wallpaper/lock (awww, hypridle, hyprlock).
The system font is a gothic serif via fontconfig. Target: **Arch / CachyOS**
(official repositories, plus a few AUR extras: tofi, wallust).

## Install (CachyOS / Arch)

```bash
# 1. packages: repo + AUR (tofi, wallust, …) via paru/yay
./bootstrap.sh

# 2. lay down the configs (from the dotfiles root)
cd ~/dotfiles
./install.sh --no-packages      # symlinks everything into ~/.config
# or manually:
ln -sfn "$PWD/config/hypr"       ~/.config/hypr
ln -sfn "$PWD/config/waybar"     ~/.config/waybar
ln -sfn "$PWD/config/rofi"       ~/.config/rofi
ln -sfn "$PWD/config/tofi"       ~/.config/tofi
ln -sfn "$PWD/config/foot"       ~/.config/foot
ln -sfn "$PWD/config/fontconfig" ~/.config/fontconfig
ln -sfn "$PWD/config/gtk-3.0"    ~/.config/gtk-3.0
ln -sfn "$PWD/config/gtk-4.0"    ~/.config/gtk-4.0
ln -sfn "$PWD/config/mako"       ~/.config/mako

# 3. start a Hyprland session from SDDM/ly
```

The same links are created by `install.sh` at the repository root.

## Layout

```text
config/hypr/
├── hyprland.conf          # entry point, sources conf.d/*
├── conf.d/
│   ├── colors.conf        # PALETTE — the one file to recolor the base theme
│   ├── env.conf           # environment variables
│   ├── monitors.conf      # monitors (+ monitors.local.conf per machine)
│   ├── input.conf         # keyboard, mouse, touchpad
│   ├── decoration.conf    # gaps, borders, blur, shadows, opacity
│   ├── animations.conf    # animations
│   ├── layouts.conf       # dwindle / master / scrolling
│   ├── rules.conf         # window and layer rules
│   ├── autostart.conf     # what starts in the session
│   └── binds.conf         # keybinds
├── hypridle.conf          # idle / lock by timeout
├── hyprlock.conf          # lock screen
├── scripts/               # controls, quick, settings, palette, theme(-mode),
│                          #   wallpaper(-picker), screenshot, clipboard, dismiss,
│                          #   filemanager, launcher, run-in-terminal,
│                          #   notifications, system-setup
├── packages.txt           # repository packages
├── aur.packages.txt       # AUR packages (paru/yay)
└── bootstrap.sh           # install packages, then symlink the configs
```

## Theme

The concept is **gothic minimalism**: near-black background, bone text, a blood
accent, thin borders, sharp corners, no blur or shadows. The palette is
**fixed** and centralized:

* Hyprland — `conf.d/colors.conf`
* Waybar — `config/waybar/colors.css`
* rofi — `config/rofi/colors.rasi`
* tofi — `config/tofi/config`
* foot — `config/foot/foot.ini`
* mako — `config/mako/config`
* swaync — `config/swaync/colors.css`

One module owns the palette: `scripts/palette.sh`. It keeps a **single**
persisted mode in `~/.config/hypr/palette-mode` — `dark`, `light` or `dynamic` —
writes the generated color files, reloads the apps that consume them and keeps
the two recolor modes mutually exclusive (enabling one disables the other).

* **dark** (default) — the fixed gothic palette above. There is no generated
  content, so every app falls back to the fixed colors.
* **light** — the "ivory" variant, recoloring Hyprland, Waybar, rofi, kitty and
  swaync.
* **dynamic** — a palette derived from the wallpaper via
  [wallust](https://codeberg.org/explosion-mental/wallust), recoloring
  Hyprland, Waybar, rofi, mako, swaync, tofi and Starship through
  `colors.dynamic.*` / `~/.cache/wallust/*`. It is colorful and fights the gothic
  look, so it is off by default.

foot, mako, tofi, hyprlock and GTK keep the fixed palette. The mode survives a
relogin; switch dark ⇄ light from the settings center (**Light theme**) or with
`SUPER + Shift + T`.

```bash
~/.config/hypr/scripts/palette.sh status         # dark | light | dynamic
~/.config/hypr/scripts/palette.sh set dynamic    # wallpaper-derived palette
~/.config/hypr/scripts/palette.sh set light      # light "ivory" palette
~/.config/hypr/scripts/palette.sh set dark       # back to the fixed gothic palette
~/.config/hypr/scripts/palette.sh toggle         # dark ⇄ light
~/.config/hypr/scripts/palette.sh clear          # drop generated colour, back to dark
```

`scripts/theme-mode.sh dark|light|toggle|status` stays as the thin dark/light
toggle for the keybind; `scripts/theme.sh [image]` applies the wallpaper and
re-applies the current mode (the image drives the palette in **dynamic** mode).

## Keybinds

The full, generated table lives in the top-level `README.md` — single source:
`config/hypr/keybinds.tsv` rendered by `scripts/gen-keybinds.sh`. The actual
binds are in `conf.d/binds.conf`; `Alt + Shift` switches the us/ru layout and
`Caps Lock` acts as Escape (both from `conf.d/input.conf`).

## Wallpaper and animation

`scripts/wallpaper.sh <file>` handles three kinds:

* **static** (png/jpg/...) — via **awww**, with a smooth transition;
* **GIF** — via awww, animated;
* **video** (mp4/webm/mkv/mov) — via **mpvpaper** (AUR package).

`scripts/theme.sh` calls `wallpaper.sh` and then re-applies the current palette
mode through `scripts/palette.sh`, so a wallpaper set in **dynamic** mode
recolors the desktop. With no image file the wallpaper is generated as a
gradient (needs imagemagick).

```bash
~/.config/hypr/scripts/wallpaper.sh ~/Pictures/wall.png
~/.config/hypr/scripts/wallpaper.sh ~/Pictures/loop.gif
~/.config/hypr/scripts/wallpaper.sh ~/Videos/wall.mp4
```

The wallpaper picker (`SUPER + W`) shows a grid of previews in rofi: it scans
`~/Pictures` (2 levels), `~/Wallpapers` and `~/.config/hypr/wallpapers`, caches
thumbnails in `~/.cache/wallpaper-picker`, and applies the chosen image together
with its palette.

```bash
~/.config/hypr/scripts/wallpaper-picker.sh
```

## Performance

Tuned for minimal input lag and lightness:

* animations disabled (`conf.d/animations.conf`);
* blur and shadows off, window opacity 1.0 (`conf.d/decoration.conf`);
* `misc:vfr = true`, `debug:damage_tracking = 2`, `render:explicit_sync = 2`;
* tearing only for games/fullscreen via `immediate` rules
  (`general:allow_tearing = true` + `conf.d/rules.conf`);
* minimal bar, no CPU/RAM/temperature or tray (`waybar/config.jsonc`);
* `nm-applet` and `blueman-applet` removed from autostart — network/Bluetooth on
  demand (`nmtui`, `bluetui`) or from Waybar;
* launcher is **tofi** (Wayland, C, lighter than rofi), authentication is
  **hyprpolkitagent** instead of polkit-gnome, clipboard is `wl-clip-persist`;
* system tuning (`install.sh --system`): **zram-generator** (compressed swap),
  **systemd-oomd** (memory pressure relief), **ananicy-cpp** (priorities),
  **irqbalance**;
* TUI tools (**yazi**, **wiremix**) inherit the foot palette — no separate theme.

## Quick controls

`SUPER + Shift + C` opens the rofi quick panel; the active toggles also show as
a red `DND · NIGHT · CAFFEINE · REC` tag on the Waybar right side (hidden when
empty). One module owns the state and the actions — `scripts/controls.sh`:

```bash
~/.config/hypr/scripts/controls.sh status          # all four states
~/.config/hypr/scripts/controls.sh dnd toggle      # mako / swaync DND
~/.config/hypr/scripts/controls.sh night on 4000   # hyprsunset (1000..10000K)
~/.config/hypr/scripts/controls.sh caffeine on     # systemd idle/sleep inhibitor
~/.config/hypr/scripts/controls.sh record start full audio
~/.config/hypr/scripts/controls.sh record stop     # ~/Videos/Recordings
```

Markers live in `~/.config/hypr/` (`dnd`, `night-light`, `caffeine`,
`recording`). `conf.d/autostart.conf` runs `restore`, so DND, night light and
caffeine come back after a login; recording never restarts by itself.
`scripts/quick.sh` is only the panel view — it asks `controls.sh` for each
state and passes the chosen row back to it. mako gets the DND mode from
`config/mako/config` (`[mode=do-not-disturb]`), swaync uses its own DND.

## Settings center (`SUPER + ,`)

A lightweight rofi menu (`scripts/settings.sh`). Changes on the fly:

* **Wallpaper** — static, animated (GIF/video) or gradient;
* **Quick controls** — DND, night light, caffeine, screen recording (opens the panel);
* **Theme** — dark gothic ⇄ wallpaper-derived palette (`palette.sh`);
* **Terminal** — foot / kitty / alacritty (written to `~/.config/hypr/terminal`);
* **SHELL** — login shell fish / bash (via `chsh`, password in the terminal);
* **Notifications** — mako / swaync (written to `~/.config/hypr/notifications`);
* **Layout** — dwindle / master / scrolling (written to `layout.dynamic.conf`);
* **Animations** — on / off (written to `animations.dynamic.conf`);
* **Light theme** — dark gothic ⇄ light "ivory" palette (`palette.sh`);
* **Random wallpaper** — random image from `~/Wallpapers` etc. at each login;
* **Bar**, **Monitors**, **Keybinds**, **Qt theme**, **Reload**, **Power**.

Terminal and notification choices go through the wrappers
`scripts/run-in-terminal.sh` and `scripts/notifications.sh` (called by the
`SUPER + Return` bind and autostart), so no manual config editing is needed.
Choice files live in `~/.config/hypr/` (including `palette-mode`,
`conf.d/layout.dynamic.conf` and `conf.d/animations.dynamic.conf`) and never
reach git; layout and animations apply instantly via `hyprctl` and survive a
relogin.

## Terminal and font

The default terminal is **foot** (Wayland-native, minimal, low latency); kitty
and alacritty are alternatives (switchable in the settings center). In server
mode: `autostart.conf` keeps `foot --server` running and `SUPER + Return` opens
`footclient` instantly. Gothic colors, JetBrainsMono Nerd Font, `dpi-aware=no`,
no cursor blink. Config: `config/foot/foot.ini`.

The system font is a gothic serif via `~/.config/fontconfig/fonts.conf`
(Cormorant Garamond → Cinzel → EB Garamond → FreeSerif), plus `gtk-3.0`/`gtk-4.0`
`settings.ini` for GTK apps. Monospace stays Nerd Font (needed for Waybar
glyphs). If Cormorant/Cinzel are not installed, FreeSerif from `gnu-free-fonts`
is used instead.

**Qt** is configured through **qt6ct** (`config/qt6ct/qt6ct.conf` + the palette
`colors/gothic.conf`, Fusion style, gothic fonts) and qt5ct for Qt5
(`config/qt5ct/`). Enabled by `QT_QPA_PLATFORMTHEME=qt6ct` in `conf.d/env.conf`.
If qt6ct does not pick the scheme up via `~`, open `qt6ct` once and select the
**gothic** scheme — the path is then stored absolute.

## Russian keyboard layout

Two layers so Latin shortcuts keep working on a Russian (ЙЦУКЕН) layout:

* **Vim / Neovim** — `set langmap=` in `.vimrc`: Normal-mode commands and
  mappings behave as Latin while Insert inserts Cyrillic, so `dd`, `gg`, `:wq`
  work without switching layout.
* **Everywhere** — **keyd** (`etc/keyd/default.conf`, enabled by `install.sh
  --system`): while Ctrl/Alt/Super is held, Russian letters act as the matching
  Latin ones, so shortcuts work in any app (micro, browser, ...). Plain typing is
  untouched (Russian still types Russian).

## Alternatives (heavier)

The set is built from light components: **mako** (a minimal notification daemon)
and **Waybar** (a C++/GTK bar). For richer features, the options below are
heavier in memory and runtime but are a couple of steps to enable:

* **swaync** — a notification/control center (GTK4). The config already lives in
  `config/swaync/` and follows the wallpaper palette. Enable: `sudo pacman -S
  swaync`, then replace `mako` with `swaync` in `conf.d/autostart.conf` (or pick
  it in the settings center).
* **HyprPanel** — an AGS/Astal bar (needs the `ags`/`astal` runtime and GJS),
  installed from the AUR (`hyprpanel`); it manages its own config through a GUI,
  and Waybar is then removed from autostart. Noticeably heavier than Waybar.
