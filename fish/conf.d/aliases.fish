# Аббревиатуры (разворачиваются после пробела — удобно, видно финальную команду)
abbr ls 'eza --group-directories-first'
abbr l 'eza -l --group-directories-first'
abbr ll 'eza -lh --group-directories-first --git'
abbr la 'eza -a --group-directories-first'
abbr lt 'eza --tree --level=2 --group-directories-first'
abbr .. 'cd ..'
abbr ... 'cd ../..'
abbr .... 'cd ../../..'
abbr home 'cd ~'
abbr c clear
abbr cls 'clear; and eza --group-directories-first'
abbr v vim
abbr m micro
# fd: на Arch/CachyOS бинарь называется fd, на Debian/Ubuntu — fdfind.
# Подсказываем только там, где нужного имени нет, чтобы не затенять рабочую команду.
if command -q fdfind; and not command -q fd
    abbr fd fdfind
    abbr f fdfind
end
abbr ff fastfetch
abbr b bat

abbr gs 'git status'
abbr ga 'git add .'
abbr gc 'git commit -m'
abbr gp 'git push'
abbr gl 'git log --oneline --graph'

# update / upgrade / cleanup — функции (distro-aware), см. functions/*.fish
abbr df 'df -h'
abbr du 'du -sh *'
abbr free 'free -m -h'
abbr myip 'curl ifconfig.me'
abbr ports 'netstat -tulanp'
abbr untar 'tar -zxvf'

# Безопасные алиасы (работают в т.ч. в скриптах, не только интерактивно)
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
alias mkdir='mkdir -pv'

# Цветной вывод (тоже алиасы — нужны для совместимости)
alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
