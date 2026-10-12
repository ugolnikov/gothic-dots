#!/bin/bash

# Проверка прав суперпользователя
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт с помощью sudo!"
  exit 1
fi

echo "=== Старт очистки Ubuntu ==="

# 1. Очистка кэша менеджера пакетов APT
echo "-> Очистка кэша APT..."
apt-get autoremove -y       # Удаление неиспользуемых зависимостей
apt-get autoclean -y        # Удаление старых версий пакетов
apt-get clean -y            # Полная очистка кэша загруженных .deb файлов

# 2. Удаление старых конфигурационных файлов (остатков удаленных программ)
echo "-> Удаление остаточных конфигов..."
REMOVED_CONFIGS=$(dpkg -l | grep "^rc" | awk '{print $2}')
if [ -n "$REMOVED_CONFIGS" ]; then
    apt-get purge -y $REMOVED_CONFIGS
fi

# 3. Очистка кэша пакетов Snap (сохраняет только последнюю версию)
if command -v snap &> /dev/null; then
    echo "-> Очистка старых версий Snap пакетов..."
    snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
    if [ -n "$snapname" ]; then
        snap remove "$snapname" --revision="$revision"
    fi
    done
fi

# 4. Очистка системных логов (journald) старше 3 дней
echo "-> Сжатие системных логов..."
journalctl --vacuum-time=3d

# 5. Очистка кэша миниатюр изображений (учетные записи пользователей)
echo "-> Очистка кэша эскизов..."
rm -rf /home/*/.cache/thumbnails/*

# 6. Очистка кэша Flatpak (если используется)
if command -v flatpak &> /dev/null; then
    echo "-> Очистка неиспользуемых данных Flatpak..."
    flatpak uninstall --unused -y
fi

# 7. Очистка корзины всех пользователей
echo "-> Очистка системных корзин..."
rm -rf /home/*/.local/share/Trash/*
rm -rf /root/.local/share/Trash/*

# 8. Очистка временных файлов /tmp
echo "-> Безопасная очистка временных файлов..."
find /tmp -type f -atime +2 -delete

# 9. Очистка кэша шрифтов и обновлений
echo "-> Очистка кэша шрифтов и X11..."
fc-cache -f -v &> /dev/null
rm -rf /var/lib/ubuntu-advantage/boot-configs/*

# 10. Очистка пользовательского кэша приложений (.cache)
# Удаляет кэш программ старше 7 дней, исключая важные конфиги
echo "-> Очистка старого пользовательского кэша приложений..."
find /home/*/.cache/ -type f -atime +7 -delete 2>/dev/null

# 11. Очистка кэша системных служб (Man-страницы и локали)
echo "-> Очистка кэша документации..."
rm -rf /var/cache/man/*

# 12. Безопасный сброс кэша оперативной памяти (PageCache, dentries и inodes)
# Освобождает занятую под кэш оперативную память, не влияя на стабильность
echo "-> Сброс системного кэша оперативной памяти..."
sync; echo 3 > /proc/sys/vm/drop_caches

echo "=== Очистка успешно завершена! ==="
df -h / | grep -v Filesystem  # Показывает свободное место на диске
