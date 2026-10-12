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
fish_add_path /root/.opencode/bin



set -gx BAT_THEME Dracula
set -gx LANG en_US.UTF-8
