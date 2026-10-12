# Secrets (API keys, tokens) — не в репозитории
if test -f ~/.secrets.fish
    source ~/.secrets.fish
end

# Added by jcode installer
if not contains "$HOME/.local/bin" $PATH
    set -gx PATH "$HOME/.local/bin" $PATH
end
