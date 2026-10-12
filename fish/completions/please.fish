# Комплетция для please — подсказывает команды из истории
complete -c please -f -k -a '(history search --max 100)' -d "команда из истории"
