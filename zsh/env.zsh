# PATH и базовые переменные окружения
export DOTFILES="${DOTFILES:-$HOME/dotfiles}"
export PATH="$DOTFILES/bin:$HOME/.local/bin:$PATH"
. "$HOME/.local/bin/env"

# fnm (Node.js)
FNM_PATH="/root/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Go


# opencode
export PATH=/root/.opencode/bin:$PATH

# fzf + zoxide
source <(fzf --zsh)
eval "$(zoxide init zsh)"

# Комплетция для z — ищет в базе zoxide (а не только локальные папки)
#shellcheck disable=SC2154
__zoxide_z_complete() {
    [[ "${#words[@]}" -eq "${CURRENT}" ]] || return 0
    if [[ "${#words[@]}" -eq 2 ]]; then
        _cd -/
    elif [[ "${words[-1]}" == '' ]]; then
        __zoxide_result="$(\command zoxide query --exclude "$(__zoxide_pwd || \builtin true)" --interactive -- "${words[2,-1]}" 2>/dev/null)" || __zoxide_result=''
        compadd -Q -S "" -- ""
        \builtin bindkey '\e[0n' '__zoxide_z_complete_helper'
        \builtin printf '\e[5n'
        return 0
    else
        # zoxide query --list + фильтр по введённому префиксу
        local -a dirs
        dirs=("${(@f)$(zoxide query --list 2>/dev/null)}")
        local prefix="${words[-1]}"
        [[ -n "$prefix" ]] && dirs=("${(@M)dirs:#${prefix}*}")
        _describe -t zoxide "zoxide dirs" dirs
    fi
}



export BAT_THEME="Dracula"
export LANG=en_US.UTF-8
