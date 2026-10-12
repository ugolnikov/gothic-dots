# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
xterm-color) color_prompt=yes ;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
  if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    # We have color support; assume it's compliant with Ecma-48
    # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    # a case would tend to support setf rather than setaf.)
    color_prompt=yes
  else
    color_prompt=
  fi
fi

if [ "$color_prompt" = yes ]; then
  PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
  PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm* | rxvt*)
  PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
  ;;
*)
  ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
  _dc="$HOME/.config/dircolors/gothic"
  if [ -r "$_dc" ]; then
    eval "$(dircolors -b "$_dc")"   # gothic, blue-free
  else
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  fi
  unset _dc
  [ -r "$HOME/.config/dircolors/eza" ] && export EZA_COLORS="$(cat "$HOME/.config/dircolors/eza")"
  [ -r "$HOME/.config/dircolors/fzf" ] && export FZF_DEFAULT_OPTS="$(cat "$HOME/.config/dircolors/fzf")"
  [ -r "$HOME/.config/dircolors/grep" ] && export GREP_COLORS="$(cat "$HOME/.config/dircolors/grep")"
  export BAT_THEME="gothic"
  alias ls='eza --group-directories-first'
  #alias dir='dir --color=auto'
  #alias vdir='vdir --color=auto'

  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='eza -lh --group-directories-first --git'
alias la='eza -a --group-directories-first'
alias l='eza -l --group-directories-first'
alias lt='eza --tree --level=2 --group-directories-first'
alias v='nvim'
# fd: на Arch/CachyOS бинарь называется fd, на Debian/Ubuntu — fdfind. Подсказываем
# alias только там, где нужного имени нет, чтобы не затенять рабочую команду.
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  alias fd='fdfind'
fi
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias home='cd ~'

# Пакетные помощники — pacman/apt aware, зеркалят fish-функции update/upgrade/cleanup.
if command -v pacman >/dev/null 2>&1; then
  update() { sudo pacman -Sy; }
  upgrade() {
    if command -v paru >/dev/null 2>&1; then paru -Syu
    elif command -v yay >/dev/null 2>&1; then yay -Syu
    else sudo pacman -Syu; fi
  }
  cleanup() {
    local orphans
    orphans="$(pacman -Qtdq 2>/dev/null)"
    # shellcheck disable=SC2086  # word list of package names, intentional
    [ -n "$orphans" ] && sudo pacman -Rns $orphans
    if command -v paccache >/dev/null 2>&1; then sudo paccache -rk1; sudo paccache -ruk0; fi
    if command -v paru >/dev/null 2>&1; then paru -Sc --noconfirm
    elif command -v yay >/dev/null 2>&1; then yay -Sc --noconfirm; fi
  }
  alias remove='cleanup'
  alias clean='cleanup'
else
  update() { sudo apt update; }
  upgrade() { sudo apt update && sudo apt upgrade; }
  cleanup() { sudo apt autoremove -y && sudo apt autoclean && sudo apt clean; }
  alias remove='sudo apt autoremove'
  alias clean='sudo apt autoclean'
fi

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
#if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
#    . /etc/bash_completion
#fi

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
export PATH="$HOME/.local/bin:$PATH"

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# fnm
FNM_PATH="$HOME/.local/share/fnm"
if command -v fnm >/dev/null 2>&1; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell bash)"
fi

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# secrets (API keys, tokens) для bash-фолбэка
[ -f ~/.secrets.sh ] && . ~/.secrets.sh

# prompt & tools — только если установлены
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

# Added by jcode installer
export PATH="$HOME/.local/bin:$PATH"
