# Приветствие при запуске (аналог fish_greeting)
if command -v fastfetch &>/dev/null && [[ ! -f ~/.zsh_greeting_ran ]]; then
    touch ~/.zsh_greeting_ran
    fastfetch
else
    echo "  ╭──────────────────────────────╮"
    echo "  │  🐟  (⩾ ᆺ ⩽)  let's go!     │"
    echo "  ╰──────────────────────────────╯"
fi
