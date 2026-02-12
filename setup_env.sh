#!/bin/bash

echo "Installing tools..."
sudo apt update && sudo apt upgrade -y
sudo apt install trash-cli vim sl zsh pipx autojump wget nala fzf -y
sudo apt install tldr -y || pipx install tldr
tldr -u

echo "Installing pentest-related tools if using Kali"
sudo apt install seclists peass autorecon zaproxy


echo "Updating core user config..."
cd ~
mv .zshrc .zshrc.bak
wget -O .zshrc https://git.grml.org/f/grml-etc-core/etc/zsh/zshrc
echo "# Load autojump" >> .zshrc
echo ". /usr/share/autojump/autojump.sh" >> .zshrc
echo "export IP=$(curl ifconfig.me) >> .zshrc
mkdir -p ~/Executables/bin/
echo 'PATH="$USER/Executables/bin:$PATH"' >> .zshrc


echo "Preparing aliases"
echo "source ~/.alias" >> .zshrc
echo "alias rm='trash'" >> .alias
echo "alias update-all='sudo apt upgrade --download-only -y ; sudo apt update && sudo apt upgrade -y'" >> .alias


echo "Changing shell to zsh..."
chsh -s /bin/zsh
#echo "zsh" >> .bashrc
echo "All OK!"

echo "Installing nice dotfiles"
