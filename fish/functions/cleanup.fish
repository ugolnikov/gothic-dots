function cleanup --description 'Aggressively clean package caches, logs and caches (pacman/apt aware)'
    set -l dry_run 0
    for arg in $argv
        switch $arg
            case -n --dry-run
                set dry_run 1
            case -h --help
                printf '%s\n' \
                    'Usage: cleanup [-n|--dry-run]' \
                    '' \
                    'Maximum disk cleanup. Frees space from:' \
                    '  - package caches, orphans and residual configs (pacman/apt)' \
                    '  - journald + rotated logs, /tmp, /var/tmp' \
                    '  - disabled Snap revisions, unused Flatpak runtimes' \
                    '  - trash, thumbnails, ~/.cache and tool caches' \
                    '    (pip, npm, yarn, go, brew, docker), man/font caches' \
                    '  - page cache (drop_caches)' \
                    '' \
                    'Options:' \
                    '  -n, --dry-run  show the commands without changing anything' \
                    '  -h, --help     show this help'
                return 0
            case '*'
                echo "cleanup: unknown option: $arg" >&2
                return 2
        end
    end

    # System-wide cleanup needs root. Keep `sudo` only when we are not root.
    set -l sudo
    if test (id -u) -ne 0
        if command -q sudo
            set sudo sudo
        else
            echo 'cleanup: needs root — run as root or install sudo' >&2
            return 1
        end
    end

    set -l before (df -Pk / | awk 'NR == 2 {print $4}')
    if test $dry_run -eq 1
        echo 'cleanup: dry run, nothing will be changed'
    end

    # --- package manager ---
    if command -q pacman
        echo '→ pacman: orphaned packages and full package cache'
        set -l orphans (pacman -Qtdq 2>/dev/null)
        if test (count $orphans) -gt 0
            __cleanup_cmd $dry_run $sudo pacman -Rns $orphans
        else
            echo '  no orphans'
        end
        if command -q paccache
            __cleanup_cmd $dry_run $sudo paccache -rk0
            __cleanup_cmd $dry_run $sudo paccache -ruk0
        end
        __cleanup_cmd $dry_run $sudo pacman -Sc --noconfirm
        if command -q paru
            __cleanup_cmd $dry_run paru -Scc --noconfirm
        else if command -q yay
            __cleanup_cmd $dry_run yay -Scc --noconfirm
        end
    else if command -q apt-get
        echo '→ apt: unused packages, full caches and residual configs'
        __cleanup_cmd $dry_run $sudo apt-get autoremove --purge -y
        __cleanup_cmd $dry_run $sudo apt-get autoclean
        __cleanup_cmd $dry_run $sudo apt-get clean
        set -l residual (dpkg -l 2>/dev/null | awk '/^rc/ {print $2}')
        if test (count $residual) -gt 0
            __cleanup_cmd $dry_run $sudo apt-get purge -y $residual
        end
        __cleanup_cmd $dry_run $sudo rm -rf /var/cache/apt/archives/partial
    else
        echo 'cleanup: no supported package manager (pacman/apt), skipping' >&2
    end

    # --- system logs ---
    if command -q journalctl
        echo '→ journald: keep only the last day / 50M of logs'
        __cleanup_cmd $dry_run $sudo journalctl --rotate
        __cleanup_cmd $dry_run $sudo journalctl --vacuum-time=1d
        __cleanup_cmd $dry_run $sudo journalctl --vacuum-size=50M
    end
    echo '→ logs: remove rotated archives in /var/log'
    __cleanup_cmd $dry_run $sudo find /var/log -type f '(' -name '*.gz' -o -name '*.old' -o -name '*.1' ')' -delete

    # --- trash ---
    echo '→ trash: empty for all users'
    __cleanup_cmd $dry_run $sudo rm -rf /root/.local/share/Trash
    for home in (find /home -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
        __cleanup_cmd $dry_run $sudo rm -rf $home/.local/share/Trash
    end

    # --- temp ---
    echo '→ temp: delete files untouched for 2 days (/tmp, /var/tmp)'
    __cleanup_cmd $dry_run $sudo find /tmp -maxdepth 1 -type f -atime +2 -delete
    __cleanup_cmd $dry_run $sudo find /var/tmp -maxdepth 1 -type f -atime +2 -delete

    # --- snap: remove old, disabled revisions ---
    if command -q snap
        echo '→ snap: remove disabled revisions'
        for line in (snap list --all 2>/dev/null | awk '/disabled/ {print $1 " " $3}')
            set -l part (string split ' ' -- $line)
            __cleanup_cmd $dry_run $sudo snap remove $part[1] --revision=$part[2]
        end
    end

    # --- flatpak ---
    if command -q flatpak
        echo '→ flatpak: remove unused runtimes and app caches'
        __cleanup_cmd $dry_run flatpak uninstall --unused -y
        for cache in (find $HOME/.var/app -mindepth 2 -maxdepth 2 -type d -name cache 2>/dev/null)
            __cleanup_cmd $dry_run rm -rf $cache
        end
    end

    # --- thumbnails ---
    echo '→ thumbnails: clear image thumbnail cache'
    __cleanup_cmd $dry_run rm -rf $HOME/.cache/thumbnails

    # --- user caches ---
    echo '→ ~/.cache: delete entries untouched for 7 days'
    __cleanup_cmd $dry_run $sudo find /root/.cache -mindepth 1 -maxdepth 1 -atime +7 -exec rm -rf '{}' +
    for home in (find /home -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
        if test -d $home/.cache
            __cleanup_cmd $dry_run $sudo find $home/.cache -mindepth 1 -maxdepth 1 -atime +7 -exec rm -rf '{}' +
        end
    end

    # --- tool caches ---
    if command -q pip
        echo '→ pip: purge cache'
        __cleanup_cmd $dry_run pip cache purge
    else if command -q python3
        __cleanup_cmd $dry_run python3 -m pip cache purge
    end
    if command -q npm
        echo '→ npm: clean cache'
        __cleanup_cmd $dry_run npm cache clean --force
    end
    if command -q yarn
        echo '→ yarn: clean cache'
        __cleanup_cmd $dry_run yarn cache clean
    end
    if command -q go
        echo '→ go: clean build and module cache'
        __cleanup_cmd $dry_run go clean -cache -modcache
    end
    if command -q brew
        echo '→ brew: clean up and prune all'
        __cleanup_cmd $dry_run brew cleanup -s --prune=all
    end
    if command -q docker
        echo '→ docker: prune unused images, containers and build cache'
        __cleanup_cmd $dry_run docker system prune -af
        __cleanup_cmd $dry_run docker builder prune -af
    end

    # --- doc and font caches ---
    echo '→ caches: man pages and fonts'
    __cleanup_cmd $dry_run $sudo rm -rf /var/cache/man
    if command -q fc-cache
        __cleanup_cmd $dry_run fc-cache -f
    end

    # --- page cache ---
    echo '→ memory: drop page cache, dentries and inodes'
    __cleanup_cmd $dry_run $sudo sync
    __cleanup_cmd $dry_run $sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'

    set -l after (df -Pk / | awk 'NR == 2 {print $4}')
    set -l freed (math "$after - $before")
    if test $freed -lt 0
        set freed 0
    end
    printf 'cleanup: done, freed %d MiB on /\n' (math "floor($freed / 1024)")
    df -h /
end

# Internal helper: run a cleanup command, or just print it in dry-run mode.
# The first argument is the dry-run flag, the rest is the command to run.
function __cleanup_cmd --description 'internal: run or print a cleanup command'
    set -l dry $argv[1]
    set -l cmd $argv[2..-1]
    if test "$dry" = 1
        printf '  [dry-run] %s\n' (string join ' ' -- $cmd)
    else
        printf '  %s\n' (string join ' ' -- $cmd)
        command $cmd
    end
end
