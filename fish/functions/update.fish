function update --description 'Sync package databases (pacman/apt aware)'
    if command -q pacman
        sudo pacman -Sy
    else if command -q apt
        sudo apt update
    else
        echo "update: no supported package manager (pacman/apt)" >&2
        return 1
    end
end
