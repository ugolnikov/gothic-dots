# PATH и базовые переменные окружения
set -gx DOTFILES "$HOME/dotfiles"
fish_add_path "$DOTFILES/bin"
fish_add_path "$HOME/.local/bin"

test -f "$HOME/.local/bin/env.fish"; and source "$HOME/.local/bin/env.fish"

# fnm (Node.js) — ленивая загрузка на первом prompt'е
set -gx FNM_PATH "$HOME/.local/share/fnm"
if test -d "$FNM_PATH"
    fish_add_path "$FNM_PATH"
    function __lazy_fnm --on-event fish_prompt
        functions -e __lazy_fnm
        fnm env --shell fish | source
    end
end

# bun
set -gx BUN_INSTALL "$HOME/.bun"
fish_add_path "$BUN_INSTALL/bin"

# Go

# opencode
fish_add_path "$HOME/.opencode/bin"

# Цвета ls (готик, без синего) — fish не умеет eval dircolors, выдёргиваем значение
if command -q dircolors
    set -l _dc "$HOME/.config/dircolors/gothic"
    if test -r "$_dc"
        for _line in (dircolors -b "$_dc")
            if string match -q 'LS_COLORS=*' -- "$_line"
                set -gx LS_COLORS (string replace -r "^LS_COLORS='(.*)'.*" '$1' -- "$_line")
            end
        end
    end
end

# Цвета eza / fzf / grep (готик, без синего)
if test -r "$HOME/.config/dircolors/eza"
    set -gx EZA_COLORS (cat "$HOME/.config/dircolors/eza")
end
if test -r "$HOME/.config/dircolors/fzf"
    set -gx FZF_DEFAULT_OPTS (cat "$HOME/.config/dircolors/fzf")
end
if test -r "$HOME/.config/dircolors/grep"
    set -gx GREP_COLORS (cat "$HOME/.config/dircolors/grep")
end

set -gx BAT_THEME gothic
set -gx LANG en_US.UTF-8
