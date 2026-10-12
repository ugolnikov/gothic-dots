# dotfiles

Персональные dotfiles.

## Структура

```
.
├── .gitignore                 # Исключения для Git
├── .zshrc                     # Точка входа — грузит модули из zsh/
├── bin/
│   └── please                 # sudo-запуск команд из истории
├── zsh/
│   ├── aliases.zsh
│   ├── completions.zsh        # Комплетция для please
│   ├── env.zsh                # PATH и переменные
│   ├── greeting.zsh           # Fastfetch / ASCII-арт при запуске
│   ├── prompt.zsh             # Pure prompt
│   └── secrets.zsh.EXAMPLE    # Шаблон для API-ключей
├── fish/                      # Fish shell (альтернатива zsh)
│   ├── config.fish
│   ├── secrets.fish.EXAMPLE
│   ├── fishfile               # Плагины Fisher
│   ├── conf.d/
│   │   ├── env.fish
│   │   ├── aliases.fish
│   │   ├── interactive.fish   # fzf, zoxide
│   │   └── prompt.fish
│   ├── completions/
│   │   └── please.fish
│   └── functions/
│       └── fish_greeting.fish
├── gitconfig                  # → ~/.gitconfig
├── .editorconfig              # → ~/.editorconfig
├── tmux.conf                  # → ~/.tmux.conf
├── config/
│   └── fastfetch/             # → ~/.config/fastfetch/
│       ├── config.jsonc
│       ├── logo.txt
│       └── logo_2.txt
├── claude/                    # → ~/.claude/
│   ├── settings.json
│   └── settings.local.json.EXAMPLE
└── install.sh                 # Bootstrap через GNU Stow
```

## Установка

### Быстрая (через GNU Stow)

```bash
git clone https://github.com/ugolnikov/my-dots.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

### Ручная

```bash
cd ~/dotfiles

ln -sf $PWD/.zshrc ~/.zshrc
ln -sf $PWD/gitconfig ~/.gitconfig
ln -sf $PWD/tmux.conf ~/.tmux.conf
ln -sf $PWD/.editorconfig ~/.editorconfig

# Fastfetch
mkdir -p ~/.config && ln -sf $PWD/config/fastfetch ~/.config/fastfetch

# Claude
mkdir -p ~/.claude && ln -sf $PWD/claude/settings.json ~/.claude/settings.json

# Fish
ln -sf $PWD/fish ~/.config/fish

# Secrets (не в репозитории)
cp zsh/secrets.zsh.EXAMPLE ~/.secrets.zsh
cp fish/secrets.fish.EXAMPLE ~/.secrets.fish
# Отредактировать под свои ключи

# Машинно-специфичные переопределения Claude
cp claude/settings.local.json.EXAMPLE ~/.claude/settings.local.json
```

### Zsh-плагин

```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

### Pure prompt (Fish)

```bash
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
fisher update
```

## please

Утилита для запуска команд из истории через `sudo`. Работает в любой оболочке (zsh/fish/bash).

```
please             # последняя команда с sudo
please <TAB>       # выбрать команду из истории (комплетция)
please apt update  # sudo apt update без хождения по истории
```

Автоматически определяет родительскую оболочку (zsh/fish/bash) и читает её историю.

### Отличия от Zsh

| Zsh | Fish |
|-----|------|
| `export VAR=val` | `set -gx VAR val` |
| `alias ll='ls -alF'` | `abbr ll 'ls -alF'` (живые) / `alias` (для безопасности) |
| `source <(fzf --zsh)` | `fzf --fish | source` |
| `eval "$(zoxide init zsh)"` | `zoxide init fish | source` |
| `sudo !!` / `please <TAB>` | `please <TAB>` (bin/please — общий для всех оболочек) |
| `fnm env --shell zsh` | `fnm env --shell fish` |
