# prompt.fish — Starship prompt (replaces pure).
# If the wallpaper-derived palette exists, Starship uses it; else it reads
# ~/.config/starship.toml (the shipped gothic palette).
if type -q starship
    set -l dyn "$HOME/.cache/wallust/starship.toml"
    if test -f "$dyn"
        set -gx STARSHIP_CONFIG "$dyn"
    end
    starship init fish | source
end
