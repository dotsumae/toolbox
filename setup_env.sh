#!/bin/bash

echo "Installing tools..."
sudo apt update && sudo apt upgrade -y
sudo apt install trash-cli vim sl zsh pipx autojump wget nala fzf sd -y
sudo apt install tldr -y || pipx install tldr
tldr -u

echo "Installing pentest-related tools if using Kali"
sudo apt install seclists peass autorecon zaproxy

echo "Deploying dotfiles..."
mkdir -p $HOME/Executables/bin/

cp .alias $HOME/
cp start-pentest $HOME/Executables/bin/

echo "Updating core user config..."
cd $HOME
mv .zshrc .zshrc.bak
wget -O .zshrc https://git.grml.org/f/grml-etc-core/etc/zsh/zshrc

echo "# Load autojump" >> .zshrc
echo ". /usr/share/autojump/autojump.sh" >> .zshrc
echo 'PATH="$USER/Executables/bin:$PATH"' >> .zshrc
echo "source ~/.alias" >> .zshrc

echo "Changing shell to zsh..."
chsh -s /bin/zsh

echo "All OK!"

