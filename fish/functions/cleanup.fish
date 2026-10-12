function cleanup --description 'Clean package cache and orphans (pacman/apt aware)'
    if command -q pacman
        set -l orphans (pacman -Qtdq 2>/dev/null)
        if test (count $orphans) -gt 0
            sudo pacman -Rns $orphans
        end
        if command -q paccache
            sudo paccache -rk1
            sudo paccache -ruk0
        end
        if command -q paru
            paru -Sc --noconfirm
        else if command -q yay
            yay -Sc --noconfirm
        end
    else if command -q apt
        sudo apt autoremove -y; and sudo apt autoclean; and sudo apt clean
    else
        echo "cleanup: no supported package manager (pacman/apt)" >&2
        return 1
    end
end
