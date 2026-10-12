# Pure prompt
fpath+=($HOME/.zsh/pure)
autoload -U promptinit; promptinit
prompt pure

zstyle :prompt:pure:path color cyan
zstyle :prompt:pure:prompt:success color 121
zstyle :prompt:pure:prompt:error color red
zstyle :prompt:pure:git:branch color 242
zstyle :prompt:pure:git:dirty color yellow

# Скрываем Git-информацию в ИИ-агентах
if [[ -n $AI_AGENT$CLAUDECODE$CURSOR_AGENT$GEMINI_CLI$OPENCODE ]]; then
	zstyle :prompt:pure:git show no
fi
