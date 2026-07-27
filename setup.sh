#!/usr/bin/env bash

set -u

# Locate files stored alongside this script.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.bootstrap-backups"

# Make locally installed commands immediately available.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# List packages to install through apt, cargo, or pipx.
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
    tealdeer
    topgrade
    seclists
    peass
    autorecon
    zaproxy
    wordlists
    nmap
)

# Store packages according to their installation method.
APT_PACKAGES=()
FALLBACK_PACKAGES=()
FAILED_PACKAGES=()

echo
echo "== Workstation bootstrap =="
echo

# Check whether the current system is Kali Linux.
is_kali() {
    grep -qi '^ID=kali' /etc/os-release 2>/dev/null
}

# Append a line to a file only when it is not already present.
append_once() {
    local file="$1"
    local line="$2"

    touch "$file"
    grep -Fxq "$line" "$file" || echo "$line" >> "$file"
}

# Update apt after adding a fallback Kali mirror when necessary.
update_apt() {
    local mirror="deb https://mirror.netcologne.de/kali kali-last-snapshot main contrib non-free non-free-firmware"

    if is_kali && ! curl -fsS https://http.kali.org/kali >/dev/null 2>&1; then
        echo "Default Kali mirror is unreachable; adding the fallback mirror."

        if ! grep -RqsF "$mirror" \
            /etc/apt/sources.list \
            /etc/apt/sources.list.d/ 2>/dev/null
        then
            echo "$mirror" |
                sudo tee -a /etc/apt/sources.list >/dev/null
        fi
    fi

    sudo apt update
}

# Install a package with cargo first, then pipx.
install_fallback() {
    local package="$1"

    echo
    echo "Installing $package..."

    if command -v cargo >/dev/null 2>&1; then
        cargo install "$package" && return
    fi

    if command -v pipx >/dev/null 2>&1; then
        pipx install "$package" && return
    fi

    echo "Could not install $package."
    FAILED_PACKAGES+=("$package")
}

# Execute a desktop installation command or print it for manual execution.
desktop_command() {
    local description="$1"
    local command="$2"

    if [[ "${PRINT_DESKTOP_COMMANDS:-false}" == true ]]; then
        printf '  %s\n' "$command"
        return
    fi

    echo
    echo "$description"

    if ! bash -c "$command"; then
        echo "Command failed:"
        echo "  $command"
    fi
}

# Install optional desktop applications with their custom installers.
install_desktop_apps() {
    desktop_command "Installing Zed..." \
        'curl -fL https://zed.dev/install.sh | sh'

    desktop_command "Installing Brave..." \
        'curl -fsS https://dl.brave.com/install.sh | sh'

    desktop_command "Downloading Joplin..." \
        'mkdir -p "$HOME/.local/bin" &&
         wget -O "$HOME/.local/bin/joplin" "https://objects.joplinusercontent.com/v3.6.15/Joplin-3.6.15.AppImage?source=JoplinWebsite&type=New" &&
         chmod +x "$HOME/.local/bin/joplin"'

    desktop_command "Starting Joplin..." \
        '"$HOME/.local/bin/joplin" >/dev/null 2>&1 &'
}

# Check sudo access before making system changes.
if ! sudo -v; then
    echo "sudo is required. Exiting."
    exit 1
fi

# Update apt metadata before checking package availability.
echo "Updating package index..."
update_apt || exit 1

# Build the apt and fallback package lists before installing anything.
echo
echo "Checking package availability..."

for package in "${PACKAGES[@]}"; do
    if apt-cache show "$package" >/dev/null 2>&1; then
        APT_PACKAGES+=("$package")
    else
        FALLBACK_PACKAGES+=("$package")
    fi
done

# Upgrade installed system packages.
echo
echo "Upgrading system..."
sudo apt upgrade -y

# Install every apt-compatible package in one operation.
if [[ "${#APT_PACKAGES[@]}" -gt 0 ]]; then
    echo
    echo "Installing packages with apt..."
    sudo apt install -y "${APT_PACKAGES[@]}" || true
fi

# Send apt packages that failed to install to the fallback installers.
for package in "${APT_PACKAGES[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null |
        grep -Fq "install ok installed"
    then
        FALLBACK_PACKAGES+=("$package")
    fi
done

# Install the remaining packages with cargo or pipx.
for package in "${FALLBACK_PACKAGES[@]}"; do
    install_fallback "$package"
done

# Configure the user path for pipx-installed commands.
if command -v pipx >/dev/null 2>&1; then
    pipx ensurepath || true
fi

# Copy local aliases when an .alias file exists beside the script.
if [[ -f "$SCRIPT_DIR/.alias" ]]; then
    echo
    echo "Installing aliases..."
    cp "$SCRIPT_DIR/.alias" "$HOME/.alias"
fi

# Copy local commands from the sibling bin directory.
if [[ -d "$SCRIPT_DIR/bin" ]]; then
    echo
    echo "Installing local commands..."

    mkdir -p "$HOME/.local/bin"
    cp -a "$SCRIPT_DIR/bin/." "$HOME/.local/bin/"
fi

# Move existing configuration files into the backup directory.
echo
echo "Backing up existing configuration..."

mkdir -p "$BACKUP_DIR"

for file in .screenrc .tmux.conf .vimrc .zshrc .zshenv .zshrc.local; do
    if [[ -e "$HOME/$file" ]]; then
        mv -f "$HOME/$file" "$BACKUP_DIR/$file"
    fi
done

# Download the grml configuration files.
echo
echo "Installing grml configuration..."

wget -O "$HOME/.screenrc"    https://grml.org/console/screenrc
wget -O "$HOME/.tmux.conf"   https://grml.org/console/tmux.conf
wget -O "$HOME/.vimrc"       https://grml.org/console/vimrc
wget -O "$HOME/.zshrc"       https://grml.org/console/zshrc
wget -O "$HOME/.zshenv"      https://grml.org/console/zshenv
wget -O "$HOME/.zshrc.local" https://grml.org/console/zshrc.local

# Add local paths, autojump, and aliases to zsh.
echo
echo "Updating zsh configuration..."

append_once "$HOME/.zshrc" ""
append_once "$HOME/.zshrc" "# Local bootstrap additions"
append_once "$HOME/.zshrc" \
    'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"'

if [[ -f /usr/share/autojump/autojump.sh ]]; then
    append_once "$HOME/.zshrc" \
        '. /usr/share/autojump/autojump.sh'
fi

if [[ -f "$HOME/.alias" ]]; then
    append_once "$HOME/.zshrc" \
        'source "$HOME/.alias"'
fi

# Install desktop applications interactively or print their commands.
if [[ -t 0 ]]; then
    echo
    read -rp "Install optional desktop applications? [Y/n] " answer

    if [[ ! "$answer" =~ ^[Nn]$ ]]; then
        install_desktop_apps
    fi
else
    echo
    echo "Desktop applications were not installed."
    echo "Run these commands manually:"
    echo

    PRINT_DESKTOP_COMMANDS=true install_desktop_apps
fi

# Set zsh as the default shell.
echo
echo "Changing default shell to zsh..."
chsh -s "$(command -v zsh)"

# Print packages that require manual installation.
echo
echo "== Summary =="
echo

if [[ "${#FAILED_PACKAGES[@]}" -eq 0 ]]; then
    echo "All packages installed successfully."
else
    echo "Install these packages manually:"

    for package in "${FAILED_PACKAGES[@]}"; do
        echo "  - $package"
    done
fi

echo
echo "Backups: $BACKUP_DIR"
echo "Restart your terminal or run: exec zsh"
