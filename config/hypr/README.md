# Hyprland rice

A full Hyprland desktop: compositor, bar (Waybar), launcher (tofi), terminal
(**foot**), notifications (mako), wallpaper/lock (swww, hypridle, hyprlock).
The system font is a gothic serif via fontconfig. Target: **Arch / CachyOS**
(everything from the official repositories).

## Install (CachyOS / Arch)

```bash
# 1. packages: repo + AUR (ttf-cormorant and friends) via paru/yay
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
├── scripts/               # settings, theme(-mode), wallpaper(-picker), screenshot,
│                          #   clipboard, dismiss, filemanager, launcher,
│                          #   run-in-terminal, notifications, system-setup
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

A wallpaper-derived palette (via
[wallust](https://codeberg.org/explosion-mental/wallust)) exists but is
**disabled by default** — it is colorful and fights the gothic look. Enable it:

```bash
touch ~/.config/hypr/dynamic-theme          # enable wallpaper-derived palette
~/.config/hypr/scripts/theme.sh ~/Pictures/wall.png
rm ~/.config/hypr/dynamic-theme             # back to the gothic palette
```

When enabled, wallust recolors Hyprland, Waybar, rofi, mako, swaync, tofi and
Starship through `colors.dynamic.*` / `~/.cache/wallust/*` files. By default
those files do not exist, so the fixed gothic colors apply.

A **light ("ivory") variant** of the gothic palette is available too, reusing the
same `*.dynamic.*` files:

```bash
~/.config/hypr/scripts/theme-mode.sh light    # dark, toggle, status also work
```

It recolors Hyprland, Waybar, rofi, kitty and swaync. Because it and wallust
share the same files they are mutually exclusive — enabling one disables the
other. foot, mako, tofi, hyprlock and GTK keep the fixed palette. Toggle it from
the settings center (**Light theme**).

## Keybinds

The full, generated table lives in the top-level `README.md` — single source:
`config/hypr/keybinds.tsv` rendered by `scripts/gen-keybinds.sh`. The actual
binds are in `conf.d/binds.conf`; `SUPER + Alt + Shift` switches the us/ru
layout and `Caps Lock` acts as Escape (both from `conf.d/input.conf`).

## Wallpaper and animation

`scripts/wallpaper.sh <file>` handles three kinds:

* **static** (png/jpg/...) — via **swww**, with a smooth transition;
* **GIF** — via swww, animated;
* **video** (mp4/webm/mkv/mov) — via **mpvpaper** (AUR package).

`scripts/theme.sh` calls `wallpaper.sh` and, if wallpaper-derived theming is on,
wallust. With no image file the wallpaper is generated as a gradient (needs
imagemagick).

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

## Settings center (`SUPER + ,`)

A lightweight rofi menu (`scripts/settings.sh`). Changes on the fly:

* **Wallpaper** — static, animated (GIF/video) or gradient;
* **Theme** — gothic ⇄ wallpaper-derived palette;
* **Terminal** — foot / kitty / alacritty (written to `~/.config/hypr/terminal`);
* **SHELL** — login shell fish / bash (via `chsh`, password in the terminal);
* **Notifications** — mako / swaync (written to `~/.config/hypr/notifications`);
* **Layout** — dwindle / master / scrolling (written to `layout.dynamic.conf`);
* **Animations** — on / off (written to `animations.dynamic.conf`);
* **Light theme** — dark gothic ⇄ light "ivory" palette (`theme-mode.sh`);
* **Random wallpaper** — random image from `~/Wallpapers` etc. at each login;
* **Bar**, **Monitors**, **Keybinds**, **Qt theme**, **Reload**, **Power**.

Terminal and notification choices go through the wrappers
`scripts/run-in-terminal.sh` and `scripts/notifications.sh` (called by the
`SUPER + Return` bind and autostart), so no manual config editing is needed.
Choice files live in `~/.config/hypr/` (including `conf.d/layout.dynamic.conf`
and `conf.d/animations.dynamic.conf`) and never reach git; layout and animations
apply instantly via `hyprctl` and survive a relogin.

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
