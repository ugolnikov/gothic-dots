# Aliases
alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias lg='lazygit'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='eza -l'
unalias v 2>/dev/null
# Умный алиас для запуска текстового редактора
v() {
    if command -v nvim >/dev/null 2>&1; then
        nvim "$@"
    else
        vim "$@"
    fi
}

alias v=v
alias fd='fdfind'
alias f='fdfind'
alias ff='fastfetch'
alias b='bat'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias home='cd ~'
alias c='clear'
alias m='micro'
alias update='sudo apt update'
alias upgrade='sudo apt update && sudo apt upgrade'
alias cleanup='sudo ~/dotfiles/scripts/clean_ubuntu.sh'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
alias mkdir='mkdir -pv'
alias df='df -h'
alias du='du -sh *'
alias free='free -m -h'
alias myip='curl ifconfig.me'
alias ports='netstat -tulanp'
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph'
alias untar='tar -zxvf'
alias cls='clear && ls'
alias sudo='sudo '
alias syscheck='~/dotfiles/scripts/syscheck.sh'
myaliases() {
    echo -e "\n  \e[1;35mМои быстрые команды:\e[0m"
    echo -e "  \e[1;30m------------------------------\e[0m"

    for key val in "${(@kv)aliases}"; do
        # 1. Пропускаем служебные алиасы Oh My Zsh и предупреждения
        [[ "$key" == "current_branch" || "$val" == *"deprecated"* || "$val" == *"print -Pu2"* ]] && continue

        # 2. Очищаем значение от лишних кавычек, если они есть
        local clean_val="${val#\'}"
        clean_val="${clean_val%\'}"

        # 3. Если значение слишком длинное или содержит переносы строк, берем только первую строку
        clean_val=$(echo "$clean_val" | head -n 1)

        # Выводим только красивые, валидные алиасы
        printf "  \e[1;32m%-15s\e[0m \e[1;33m➔\e[0m   \e[0;36m%s\e[0m\n" "$key" "$clean_val"
    done | sort

    echo ""
}
alias my="myaliases"

