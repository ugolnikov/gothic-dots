#!/bin/sh
# install.sh — развернуть dotfiles через GNU Stow
# Использование: cd ~/dotfiles && ./install.sh

set -e

if ! command -v stow >/dev/null 2>&1; then
    printf 'stow не найден. Установи: sudo pacman -S stow\n' >&2
    exit 1
fi

cd "$(dirname "$0")"

# Stow для директорий
stow -v zsh
stow -v fish
stow -v bin
stow -v --no-folding config
stow -v claude

# Отдельные файлы
ln -sf "$PWD/gitconfig" ~/.gitconfig
ln -sf "$PWD/tmux.conf" ~/.tmux.conf
ln -sf "$PWD/.editorconfig" ~/.editorconfig
ln -sf "$PWD/.vimrc" ~/.vimrc

if [ ! -f ~/.vim/autoload/plug.vim ]; then
    printf 'Установка Vim-Plug...\n'
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

mkdir -p ~/.local/share/nvim/site
ln -sf ~/.vim/autoload ~/.local/share/nvim/site/autoload

# Установка плагинов Vim в тихом фоновом режиме
printf 'Установка плагинов Vim...\n'
vim +PlugInstall +qall

printf '\nГотово. Перезапусти shell или source ~/.zshrc / ~/.config/fish/config.fish\n'
