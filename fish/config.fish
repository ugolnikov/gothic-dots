# Secrets (API keys, tokens) — не в репозитории
if test -f ~/.secrets.fish
    source ~/.secrets.fish
end

# Added by jcode installer
if not contains "/root/.local/bin" $PATH
    set -gx PATH "/root/.local/bin" $PATH
end
