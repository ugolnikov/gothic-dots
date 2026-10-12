# colors.fish — готическая подсветка fish.
# Перебивает стоковые fish_color_* (зелёный / циан / жёлтый) готической
# палитрой. Те же цвета, что в config/starship.toml и конфигах Hyprland:
#   fg #d6d1c9 · ash #8b857c · blood #a31621 · violet #6c4f8f · gold #8f7a4a
# Файл отслеживается в git, поэтому переживает сброс fish_variables.

# --- Командная строка ---
set -g fish_color_normal          d6d1c9
set -g fish_color_command         d6d1c9
set -g fish_color_param           8b857c
set -g fish_color_quote           8f7a4a
set -g fish_color_comment         4a4a52
set -g fish_color_end             a31621
set -g fish_color_error           a31621
set -g fish_color_escape          6c4f8f
set -g fish_color_operator        6c4f8f
set -g fish_color_redirection     a31621
set -g fish_color_cwd             a31621
set -g fish_color_cwd_root        a31621
set -g fish_color_user            a31621
set -g fish_color_host            d6d1c9
set -g fish_color_host_remote     8f7a4a
set -g fish_color_status          a31621
set -g fish_color_cancel          a31621
set -g fish_color_autosuggestion  4a4a52
set -g fish_color_valid_path      --underline
set -g fish_color_history_current --bold
set -g fish_color_selection       d6d1c9 --background=2a2a2e
set -g fish_color_search_match    --background=2a2a2e

# --- Пейджер (автодополнение по Tab) ---
set -g fish_pager_color_background           --background=0a0a0b
set -g fish_pager_color_completion           d6d1c9
set -g fish_pager_color_description           4a4a52
set -g fish_pager_color_prefix               a31621 --bold
set -g fish_pager_color_progress             8b857c
set -g fish_pager_color_secondary_background --background=0a0a0b
set -g fish_pager_color_secondary_completion 8b857c
set -g fish_pager_color_secondary_description 4a4a52
set -g fish_pager_color_secondary_prefix     8b857c
set -g fish_pager_color_selected_background  --background=a31621
set -g fish_pager_color_selected_completion  0a0a0b
set -g fish_pager_color_selected_description 0a0a0b
set -g fish_pager_color_selected_prefix      0a0a0b --bold
