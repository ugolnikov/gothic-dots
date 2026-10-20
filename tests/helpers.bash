# Shared helpers for the palette-module test suites. Load with:
#
#     load helpers
#
# Each suite must run its setup() first: these helpers read $XDG_CONFIG_HOME
# (the throwaway config tree), $STUB_BIN (where the fake binaries go) and a log
# variable — $CALLS or $RELOAD_LOG — that records the stubbed calls.

# palette_target_rel — the generated files, config-relative, in one place.
palette_target_rel() {
    printf '%s\n' \
        hypr/conf.d/colors.dynamic.conf \
        waybar/colors.dynamic.css \
        rofi/colors.dynamic.rasi \
        kitty/colors.dynamic.conf \
        swaync/colors.dynamic.css \
        foot/colors.dynamic.ini \
        tmux/colors.dynamic.conf \
        gtk-3.0/colors.dynamic.css \
        gtk-4.0/colors.dynamic.css \
        fish/colors.dynamic.fish
}

# targets — the generated files under the throwaway config tree.
targets() {
    local rel
    while IFS= read -r rel; do
        printf '%s\n' "$XDG_CONFIG_HOME/$rel"
    done < <(palette_target_rel)
}

assert_targets_exist_empty() {
    local f
    while IFS= read -r f; do
        if [ ! -f "$f" ]; then
            echo "missing target: $f" >&2
            return 1
        fi
        if [ -s "$f" ]; then
            echo "target is not empty: $f" >&2
            return 1
        fi
    done < <(targets)
}

assert_targets_exist_nonempty() {
    local f
    while IFS= read -r f; do
        if [ ! -s "$f" ]; then
            echo "target missing or empty: $f" >&2
            return 1
        fi
    done < <(targets)
}

# expect_line <pattern> <file> — assert the file carries a consumer-visible
# definition. Explicit failure so an early miss does not pass silently.
expect_line() {
    if ! grep -q -- "$1" "$2"; then
        echo "expected '$1' in $2" >&2
        return 1
    fi
}

# assert_light_palette — каждый target несёт светлую «ivory» палитру в своём
# формате. Проверяем те определения, за которые цепляются потребители, а не
# весь файл целиком.
assert_light_palette() {
    local hypr="$XDG_CONFIG_HOME/hypr/conf.d/colors.dynamic.conf"
    local waybar="$XDG_CONFIG_HOME/waybar/colors.dynamic.css"
    local rofi="$XDG_CONFIG_HOME/rofi/colors.dynamic.rasi"
    local kitty="$XDG_CONFIG_HOME/kitty/colors.dynamic.conf"
    local swaync="$XDG_CONFIG_HOME/swaync/colors.dynamic.css"
    local foot="$XDG_CONFIG_HOME/foot/colors.dynamic.ini"
    local tmux="$XDG_CONFIG_HOME/tmux/colors.dynamic.conf"
    local gtk3="$XDG_CONFIG_HOME/gtk-3.0/colors.dynamic.css"
    local gtk4="$XDG_CONFIG_HOME/gtk-4.0/colors.dynamic.css"
    local fish="$XDG_CONFIG_HOME/fish/colors.dynamic.fish"

    expect_line 'col.active_border = rgba(8c1220ff)' "$hypr" || return 1
    expect_line 'background_color = rgba(f2efe7ff)' "$hypr" || return 1
    expect_line '@define-color base     #f2efe7;' "$waybar" || return 1
    expect_line '@define-color text     #2a2723;' "$waybar" || return 1
    expect_line 'base:      #f2efe7;' "$rofi" || return 1
    expect_line 'text:      #2a2723;' "$rofi" || return 1
    expect_line 'background              #f2efe7' "$kitty" || return 1
    expect_line 'foreground              #2a2723' "$kitty" || return 1
    expect_line '@define-color base     #f2efe7;' "$swaync" || return 1
    expect_line '@define-color text     #2a2723;' "$swaync" || return 1
    expect_line 'background=f2efe7' "$foot" || return 1
    expect_line 'foreground=2a2723' "$foot" || return 1
    expect_line 'set -g status-style "fg=#2a2723,bg=#e7e2d6"' "$tmux" || return 1
    expect_line '@define-color accent_bg_color #8c1220;' "$gtk3" || return 1
    expect_line '@define-color accent_bg_color #8c1220;' "$gtk4" || return 1
    expect_line "set -g fish_color_normal '#2a2723'" "$fish" || return 1
}

# stub_wallust — substitute the external palette generator with a fake that
# writes every target, so the dynamic path is testable without image
# processing. It records the arguments it was handed in the suite's call log
# ($WALLUST_LOG, else $CALLS, else $RELOAD_LOG). Set WALLUST_FAIL=1 to make it
# fail without writing anything.
stub_wallust() {
    local rels
    rels="$(palette_target_rel | tr '\n' ' ')"
    cat >"$STUB_BIN/wallust" <<EOF
#!/usr/bin/env bash
printf '%s\n' "wallust \$*" >>"\${WALLUST_LOG:-\${CALLS:-\$RELOAD_LOG}}"
[ "\${WALLUST_FAIL:-}" = 1 ] && exit 1
for rel in $rels; do
    f="\$XDG_CONFIG_HOME/\$rel"
    mkdir -p "\$(dirname "\$f")"
    printf 'generated from %s\n' "\$*" >"\$f"
done
EOF
    chmod +x "$STUB_BIN/wallust"
}
