function my --description 'Красивый вывод всех алиасов'
    echo -e "\n  \e[1;35mМои быстрые команды:\e[0m"
    echo -e "  \e[1;30m------------------------------\e[0m"

    # Находим все функции, которые были созданы как alias
    functions | grep -E '^function ' | while read -l line
        # Вытаскиваем имя функции
        set -l func_name (string match -r 'function (\S+)' $line)[2]

        # Проверяем, содержит ли функция описание 'alias ...'
        set -l desc (functions -D $func_name | grep 'defined by alias')

        if test -n "$desc"
            # Извлекаем тело функции (саму команду)
            # В Fish тело функции можно получить через functions func_name
            set -l body (functions $func_name | grep -v -E '^function|^end|^#' | string trim)

            # Если это обертка вида 'command $argv', убираем '$argv' для красоты
            set -l clean_body (string replace -r '\s*\$argv\s*$' '' $body)

            # Пропускаем служебный мусор или сломанные многострочные алиасы
            if string match -q '*deprecated*' $clean_body; or string match -q '*print -Pu2*' $clean_body
                continue
            end

            # Берем только первую строку, если команда сложная
            set clean_body (echo $clean_body | head -n 1)

            # Выводим с выравниванием в 15 символов
            printf "  \e[1;32m%-15s\e[0m \e[1;33m➔\e[0m   \e[0;36m%s\e[0m\n" $func_name $clean_body
        end
    end | sort

    echo ""
end

