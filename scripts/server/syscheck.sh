#!/usr/bin/env bash

# Цвета для оформления
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Сброс цвета

echo -e "${BLUE}=== 💻 СТАТУС СИСТЕМЫ ===${NC}"
uptime | awk '{print "Uptime: " $3 " " $4 " | Нагрузка (1/5/15 мин): " $(NF-2) " " $(NF-1) " " $NF}'

echo -e "\n${BLUE}=== 🧠 ОПЕРАТИВНАЯ ПАМЯТЬ ===${NC}"
free -h | grep -E "Mem" | awk '{print "Занято: " $3 " / Доступно: " $7 " (Всего: " $2 ")"}'

echo -e "\n${BLUE}=== 💽 МЕСТО НА ДИСКЕ ===${NC}"
DISK_USAGE=$(df -h / | tail -n 1 | awk '{print $5}' | cut -d'%' -f1)
df -h / | tail -n 1 | awk '{print "Занято: " $5 " (" $3 " из " $2 ") | Свободно: " $4}'
if [ "$DISK_USAGE" -gt 80 ]; then
    echo -e "${RED}[ВНИМАНИЕ] Диск заполнен более чем на 80%!${NC}"
fi

echo -e "\n${BLUE}=== 🛡️ ЗАЩИТА FAIL2BAN ===${NC}"
if command -v fail2ban-client >/dev/null 2>&1; then
    BANNED_COUNT=$(sudo fail2ban-client status sshd | grep "Currently banned:" | awk '{print $4}')
    TOTAL_BANNED=$(sudo fail2ban-client status sshd | grep "Total banned:" | awk '{print $4}')
    echo -e "Сейчас в бане: ${YELLOW}$BANNED_COUNT${NC} IP | Всего поймано ботов: ${YELLOW}$TOTAL_BANNED${NC}"
else
    echo -e "  fail2ban не установлен (${YELLOW}пропуск${NC})"
fi

echo -e "\n${BLUE}=== 🐘 БАЗА ДАННЫХ (POSTGRES) ===${NC}"
if command -v psql >/dev/null 2>&1 && id postgres >/dev/null 2>&1; then
    sudo -u postgres psql -c "SELECT count(*), state FROM pg_stat_activity GROUP BY state;" 2>/dev/null | grep -v "row" | grep -v "^-" | sed 's/^/  /'
else
    echo -e "  postgres не установлен (${YELLOW}пропуск${NC})"
fi

echo -e "\n${BLUE}=== 🔥 ТОП ПРОЦЕССОВ (CPU) ===${NC}"
ps -eo pcpu,pmem,comm --sort=-pcpu | head -n 4 | sed 's/^/  /'
