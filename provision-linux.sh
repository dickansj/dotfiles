#!/usr/bin/env bash

# set up input
exec </dev/tty >/dev/tty

# make sure we're in the right place...
cd "$(dirname "$0")"
DOTFILES_ROOT=$(pwd -P)

# symlink the designated dotfiles
echo "Linking dotfiles; hang out for a second to answer potential prompts about overwriting..."
./install_symlinks.sh

# ssh config
echo "Creating SSH configuration..."
mkdir -p ~/.ssh
cp resources/ssh_config.base ~/.ssh/config

# make sure we're running in a local git working copy
#  (this hooks us in if we were set up from the bootstrap script)
if [[ ! -d .git ]]; then
  (
    # don't look at the ~/.gitconfig
    unset HOME
    git init
    git remote add origin https://github.com/dickansj/dotfiles.git
    git fetch
    git reset origin/master
    git branch --set-upstream-to=origin/master master
    git checkout .
  )
fi
# swap to ssh; credentials can get added later
git remote set-url origin git@github.com:dickansj/dotfiles.git

# Projects folder is where most code stuff lives; link this there, too,
#  because otherwise I'll forget where it is
mkdir -p ~/Projects
ln -s $DOTFILES_ROOT ~/Projects/dotfiles

# any vim bundles
vim +PluginInstall +qall

# Install pyenv
git clone https://github.com/pyenv/pyenv.git $HOME/.pyenv
git clone https://github.com/pyenv/pyenv-update.git $HOME/.pyenv/plugins/pyenv-update

cd ~
echo "And that's it! You're good to go."
