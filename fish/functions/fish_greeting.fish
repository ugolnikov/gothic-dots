function fish_greeting
    if command -q fastfetch
        # Первый запуск — fastfetch, потом только ASCII
        if not set -q fish_greeting_ran
            set -U fish_greeting_ran 1
            fastfetch
            return
        end
    end

    # Приветствие на последующие запуски
    set_color brcyan
    echo "  ╭──────────────────────────────╮"
    echo "  │  🐟  (⩾ ᆺ ⩽)  let's go!      │"
    echo "  ╰──────────────────────────────╯"
    set_color normal
end
