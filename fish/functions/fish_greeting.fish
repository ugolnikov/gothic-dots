function fish_greeting
    if command -q fastfetch
        # Первый запуск сессии — fastfetch с готическим крестом
        if not set -q fish_greeting_ran
            set -U fish_greeting_ran 1
            fastfetch
            return
        end
    end

    # Дальше — маленький крест в кровавом цвете
    set_color a31621
    echo '  █'
    echo '█████'
    echo '  █'
    echo '  █'
    set_color normal
end
