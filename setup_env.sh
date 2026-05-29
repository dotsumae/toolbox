#!/bin/bash
echo "Working with Kali [Y/n] ?"
read -n 1 ans
if [[ $ans == "n"]]; then
    echo "Getting the alternative mirror"
    echo "deb https://mirror.netcologne.de/kali kali-last-snapshot main contrib non-free non-free-firmware" | sudo tee -a /etc/apt/sources.list
fi

echo "Installing tools..."
sudo apt update && sudo apt upgrade -y
sudo apt install trash-cli vim sl zsh pipx autojump wget nala fzf sd -y
sudo apt install tldr -y || pipx install tldr
tldr -u

echo "Installing pentest-related tools if using Kali"
sudo apt install seclists peass autorecon zaproxy wordlists

echo "Deploying dotfiles..."
mkdir -p $HOME/Executables/bin/

cp .alias $HOME/
cp bin/start-pentest $HOME/Executables/bin/

echo "Updating core user config..."
cd $HOME
mv .zshrc .zshrc.bak
wget -O .screenrc   https://grml.org/console/screenrc
wget -O .tmux.conf  https://grml.org/console/tmux.conf
wget -O .vimrc      https://grml.org/console/vimrc
wget -O .zshrc      https://grml.org/console/zshrc
wget -O .zshenv     https://grml.org/console/zshenv
wget -O .zshrc.local https://grml.org/console/zshrc.local
#wget -O .zshrc https://git.grml.org/f/grml-etc-core/etc/zsh/zshrc

echo "# Load autojump" >> .zshrc
echo ". /usr/share/autojump/autojump.sh" >> .zshrc
echo 'PATH="$USER/Executables/bin:$PATH"' >> .zshrc
echo "source ~/.alias" >> .zshrc

echo "Changing shell to zsh..."
chsh -s /bin/zsh

echo "All OK!"

