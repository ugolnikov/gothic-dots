# fzf — интерактивный поиск (только если установлен)
status is-interactive; and command -q fzf; and fzf --fish | source

# zoxide — умный cd (только если установлен)
status is-interactive; and command -q zoxide; and zoxide init fish | source
