export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh

# Secrets (API keys, tokens) — не в репозитории
[[ -f ~/.secrets.zsh ]] && source ~/.secrets.zsh

# Dotfiles-модули
DOTFILES="${DOTFILES:-$HOME/dotfiles}"
for f in $DOTFILES/zsh/*.zsh; do [ -f $f ] && source $f; done

# Added by jcode installer
export PATH="/root/.local/bin:$PATH"

# bun completions
[ -s "/root/.bun/_bun" ] && source "/root/.bun/_bun"
