#!/usr/bin/env bash
set -euo pipefail

# Packages available from Kali repositories

echo "Updating package lists..."
sudo apt update
echo "Installing packages..."
sudo apt install -y \
    curl \
    wget \
    git \
    python3-pip \
    pipx \
    zoxide \
    tealdeer \
    autorecon \
    penelope \
    arsenal-ng \
    gpaste-2

echo "Configuring pipx..."
pipx ensurepath
pipx install topgrade

# Brave Browser

if ! command -v brave-browser >/dev/null 2>&1; then
    echo "Installing Brave Browser..."
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
    sudo apt update
    sudo apt install -y brave-browser
fi

# Zed Editor

if ! command -v zed >/dev/null 2>&1; then
    echo "Installing Zed..."
    curl -f https://zed.dev/install.sh | sh
fi

# Aliases and shell functions

ALIASES_FILE="$HOME/.alias"
cat > "$ALIASES_FILE" <<'EOF'

# Add an entry to /etc/hosts if missing
#
# Usage:
#   addhost 10.10.11.123 target.htb

addhost() {
    local ip="$1"
    local host="$2"
    local tmp
    tmp="$(mktemp)"
    sudo awk -v ip="$ip" -v host="$host" '
        {
            if ($1 == ip)
                next
            for (i = 2; i <= NF; i++)
                if ($i == host)
                    next
            print
        }
    ' /etc/hosts > "$tmp"
    echo "$ip $host" >> "$tmp"
    sudo cp "$tmp" /etc/hosts
    rm -f "$tmp"
    echo "$host -> $ip"
}

# Run AutoRecon against one target
#
# - Scans every TCP port from 1 through 65535
# - Excludes every plugin carrying the "long" tag
# - Uses AutoRecon's single-target output structure
#
# Usage:
#   ar 10.10.11.123
#   ar target.htb
ar() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: ar <IP-or-hostname>" >&2
        return 1
    fi
    local target="$1"
    autorecon \
        --single-target \
        --ports T:1-65535 \
        --exclude-tags long \
        "$target"
}

EOF

# zoxide configuration

if ! grep -q "zoxide init bash" "$HOME/.bashrc"; then
    echo 'eval "$(zoxide init bash)"' >> "$HOME/.bashrc"
fi

# Source custom aliases

if ! grep -q ".alias" "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'EOF'
# CTF bootstrap aliases
[ -f ~/.alias ] && source ~/.alias
EOF
fi

# tealdeer
echo "Updating tealdeer cache..."
tldr --update || true
echo
echo "Installation complete."
echo "Restart your shell or run:"
echo "    source ~/.bashrc"
