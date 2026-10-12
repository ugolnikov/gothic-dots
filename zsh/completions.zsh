#compdef please
# Комплетция для please — подсказывает команды из истории

zstyle ':completion:*:please:*' list-max 0

_please() {
  local -a cmds
  cmds=("${(@f)$(fc -ln 1 | tac | awk '!seen[$0]++' | head -100)}")
  compadd -U -Q -- "${cmds[@]}"
}

compdef _please please
