# Автодополнение для gothic. Глаголы и подкоманды повторяют `gothic help`;
# при добавлении глагола обновите обе таблицы.

set -l verbs status toggle theme wall session record ambience preset eventd keyboard scratchpad power battery monitors keybinds settings menu doctor update snapshot snapshots diff rollback clean logs version help

complete -c gothic -f
complete -c gothic -s h -l help -d справка
complete -c gothic -s v -l version -d 'ревизия репозитория'

complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a status -d 'сводка состояния рабочего стола'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a toggle -d 'переключатели сессии'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a theme -d палитра
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a wall -d обои
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a session -d 'сохранённые раскладки окон'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a record -d 'запись экрана'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a ambience -d 'расписание дня'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a preset -d 'наборы настроек'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a eventd -d 'демон событий Hyprland'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a keyboard -d 'раскладка по классу окна'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a scratchpad -d 'именованные дропдауны'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a power -d 'профиль питания'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a battery -d 'порог батареи'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a monitors -d 'раскладка мониторов'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a keybinds -d 'список биндов'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a settings -d 'центр настроек'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a menu -d лаунчер
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a doctor -d 'проверка здоровья райса'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a update -d 'обновление системы'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a snapshot -d 'снимок состояния'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a snapshots -d 'список снимков'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a diff -d 'разница со снимком'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a rollback -d 'откат к снимку'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a clean -d очистка
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a logs -d 'лог Hyprland'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a version -d 'ревизия репозитория'
complete -c gothic -n "not __fish_seen_subcommand_from $verbs" -a help -d справка

complete -c gothic -n '__fish_seen_subcommand_from toggle' -a 'dnd night caffeine record' -d переключатель
complete -c gothic -n '__fish_seen_subcommand_from toggle' -a 'on off toggle' -d действие

complete -c gothic -n '__fish_seen_subcommand_from theme' -a 'dark light dynamic' -d 'режим палитры'
complete -c gothic -n '__fish_seen_subcommand_from theme' -a 'toggle status clear' -d 'переключить, показать, сбросить'

complete -c gothic -n '__fish_seen_subcommand_from wall' -a pick -d 'выбрать обои'
complete -c gothic -n '__fish_seen_subcommand_from wall' -F

complete -c gothic -n '__fish_seen_subcommand_from session' -a 'save restore list show delete menu' -d действие
complete -c gothic -n '__fish_seen_subcommand_from session' -l dry-run -d 'показать план, ничего не меняя'

complete -c gothic -n '__fish_seen_subcommand_from record' -a 'start stop status' -d действие
complete -c gothic -n '__fish_seen_subcommand_from record' -a 'full region' -d 'область захвата'
complete -c gothic -n '__fish_seen_subcommand_from record' -a audio -d 'с дорожкой звука'

complete -c gothic -n '__fish_seen_subcommand_from ambience' -a 'status on off toggle tick next' -d действие
complete -c gothic -n '__fish_seen_subcommand_from preset' -a 'apply off current list show menu' -d действие
complete -c gothic -n '__fish_seen_subcommand_from eventd' -a 'status run' -d действие
complete -c gothic -n '__fish_seen_subcommand_from keyboard' -a 'status list clear' -d действие
complete -c gothic -n '__fish_seen_subcommand_from scratchpad' -a 'toggle menu list status' -d действие
complete -c gothic -n '__fish_seen_subcommand_from power' -a 'status saver balanced performance cycle menu' -d действие
complete -c gothic -n '__fish_seen_subcommand_from battery' -a 'status check' -d действие
complete -c gothic -n '__fish_seen_subcommand_from monitors' -a 'save apply list show delete current auto autoload menu status' -d действие
