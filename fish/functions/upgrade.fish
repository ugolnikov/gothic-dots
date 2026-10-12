function upgrade --description 'Upgrade the system (pacman/CachyOS/apt aware)'
    if command -q pacman
        if command -q paru
            paru -Syu
        else if command -q yay
            yay -Syu
        else
            sudo pacman -Syu
        end
    else if command -q apt
        sudo apt update; and sudo apt upgrade
    else
        echo "upgrade: no supported package manager (pacman/apt)" >&2
        return 1
    end
end
