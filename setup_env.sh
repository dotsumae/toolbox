#!/bin/bash

set -u

# Print script title.
echo
echo "== Workstation bootstrap =="
echo

# List packages to install, assuming the same name for apt, cargo, and pipx.
PACKAGES=(
    trash-cli
    vim
    sl
    zsh
    pipx
    cargo
    autojump
    wget
    nala
    fzf
    sd
    tldr
    topgrade

    seclists
    peass
    autorecon
    zaproxy
    wordlists
    nmap
    gobuster
    nikto
    smbclient
    smbmap
    whatweb
    sslscan
)

# Store packages that could not be installed automatically.
FAILED_PACKAGES=()

# Store overwritten config files in one simple backup directory.
BACKUP_DIR="$HOME/.bootstrap-backups"

# Check if the current system is Kali Linux.
is_kali() {
    grep -qi '^ID=kali' /etc/os-release 2>/dev/null
}

# Append a line to a file only if it is not already present.
append_once() {
    local file="$1"
    local line="$2"

    touch "$file"

    if ! grep -Fxq "$line" "$file"; then
        echo "$line" >> "$file"
    fi
}

# Update apt, adding an alternative Kali mirror if the default Kali mirror is unreachable.
update_apt() {
    local mirror

    mirror="deb https://mirror.netcologne.de/kali kali-last-snapshot main contrib non-free non-free-firmware"

    echo
    echo "Updating package index..."

    if is_kali && ! curl -fsS https://http.kali.org/kali >/dev/null 2>&1; then
        echo "Default Kali mirror seems unreachable. Trying alternative mirror..."

        if ! grep -RqsF "$mirror" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
            echo "$mirror" | sudo tee -a /etc/apt/sources.list >/dev/null
        fi
    fi

    sudo apt update
}

# Install a package using apt first, then cargo, then pipx.
install_tool() {
    local package="$1"

    echo
    echo "Installing $package..."

    if apt-cache show "$package" >/dev/null 2>&1; then
        sudo apt install -y "$package" && return 0
        echo "apt failed for $package."
    fi

    if command -v cargo >/dev/null 2>&1; then
        cargo install "$package" && return 0
        echo "cargo failed for $package."
    fi

    if command -v pipx >/dev/null 2>&1; then
        pipx install "$package" && return 0
        echo "pipx failed for $package."
    fi

    echo "Could not install $package."
    FAILED_PACKAGES+=("$package")
}

# Update and upgrade the system.
update_apt || exit 1

echo
echo "Upgrading system..."
sudo apt upgrade -y

# Install all configured packages.
echo
echo "Installing tools..."

for package in "${PACKAGES[@]}"; do
    install_tool "$package"
done

# Make pipx-installed tools available in future shells.
if command -v pipx >/dev/null 2>&1; then
    pipx ensurepath || true
fi

# Backup existing grml-managed config files.
echo
echo "Backing up existing config files..."

mkdir -p "$BACKUP_DIR"

for file in .screenrc .tmux.conf .vimrc .zshrc .zshenv .zshrc.local; do
    if [[ -f "$HOME/$file" ]]; then
        mv -f "$HOME/$file" "$BACKUP_DIR/$file"
    fi
done

# Download grml configuration files.
echo
echo "Installing grml configs..."

wget -O "$HOME/.screenrc"     https://grml.org/console/screenrc
wget -O "$HOME/.tmux.conf"    https://grml.org/console/tmux.conf
wget -O "$HOME/.vimrc"        https://grml.org/console/vimrc
wget -O "$HOME/.zshrc"        https://grml.org/console/zshrc
wget -O "$HOME/.zshenv"       https://grml.org/console/zshenv
wget -O "$HOME/.zshrc.local"  https://grml.org/console/zshrc.local

# Add local zsh customizations.
echo
echo "Updating zsh config..."

append_once "$HOME/.zshrc" ""
append_once "$HOME/.zshrc" "# Local bootstrap additions"
append_once "$HOME/.zshrc" "export PATH=\"\$HOME/Executables/bin:\$HOME/.cargo/bin:\$HOME/.local/bin:\$PATH\""

if [[ -f /usr/share/autojump/autojump.sh ]]; then
    append_once "$HOME/.zshrc" ". /usr/share/autojump/autojump.sh"
fi

if [[ -f "$HOME/.alias" ]]; then
    append_once "$HOME/.zshrc" "source \"\$HOME/.alias\""
fi

# Set zsh as the default shell.
echo
echo "Changing default shell to zsh..."
chsh -s "$(command -v zsh)" || echo "Could not change default shell to zsh."

# Print final installation summary.
echo
echo "== Summary =="
echo

if [[ "${#FAILED_PACKAGES[@]}" -eq 0 ]]; then
    echo "All packages installed successfully."
else
    echo "Some packages could not be installed automatically:"
    echo

    for package in "${FAILED_PACKAGES[@]}"; do
        echo "  - $package"
    done

    echo
    echo "Install these manually if you still need them."
fi

# Finish.
echo
echo "All done."
echo "Backups are stored in: $BACKUP_DIR"
echo "Restart your terminal or run: exec zsh"
