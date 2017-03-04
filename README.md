My dotfiles, to get a Mac or Linux computer running the way I like it. 

## Installation
To get the whole repo: 
```shell-script
git clone --recursive https://github.com/sjml/dotfiles ~/.dotfiles
```

To bootstrap onto a fresh computer (that may not have git, like Macs out of the box): 
```shell-script
curl -fsSL https://raw.githubusercontent.com/sjml/dotfiles/master/bootstrap.sh | bash
```

## What it does
Running `provision-mac.sh` on a clean user account will:
  * Take everything in this directory that ends with `.symlink` and make a
    symbolic link to it in the home directory, minus the `.symlink` and
    prepended with a `.`
  * Symlink files in `osx-launchagents` to ~/Library/LaunchAgents
  * Generate a set of local SSH keys
  * Install [homebrew](http://brew.sh)
  * Attempt to change the default shell to zsh
  * Make a `~/Projects` directory and symlink the dotfiles there
  * Install all the packages listed in the Brewfile
  * Install all GUI applications listed in the Cask section of the Brewfile
  * Install Inconsolata and Hack fonts
  * Attempt to install Mac App Store stuff from the mas section of the Brewfile
  * Install a set of vim bundles, managed by [Vundle](https://github.com/VundleVim/Vundle.vim)
  * Install pip
  * Install all packages listed in `python-packages.txt`
  * Install the zsh-compatible version of nvm
  * Use that nvm to install Node.js, yarn, and a few node utilities
  * Set up appearance of Terminal.app
  * Set up the Dock

The `provision-linux.sh` is much simpler because I don't have root on most Linux
machines I use, and tend to not have them quite as customized. All it does:
  * Attempt to change the default shell to zsh
  * Symlink the designated dotfiles
  * Install the vim bundles
  * Install pip, but not the Python packages
  * Install zsh-nvm, Node.js, and yarn, but nothing else


## Custom ZSH prompt

My tweaked setup for ZSH includes a prompt that does some fun things. 

![Basic](resources/prompt-shots/suggestions.png)
It's a double-tall prompt (controversial, but I like being able to easily skim for inputs). It
show your current working directory, username, machine name, and time. It does simple syntax
coloring and suggestions based on previous inputs. 

![Suggestions](resources/prompt-shots/brew-cleanup.png)
This is particular handy for commands that are kinda wonky but you may execute periodically. 

![Path Shortening](resources/prompt-shots/path-shortening.png)
It does clever shortening to get as much relevant information into the heads-up display as
possible. Each path component is shortened as much as it can be without becoming ambiguous.

![Root Warning](resources/prompt-shots/root-prompt.png)
It dramatically changes when you're working with root privileges so you're less likely to 
accidentally screw something up. 

![Virtual Environment](resources/prompt-shots/virtualenv.png)
A cute little snake appears when you've activated a Python virtual environment. 

![Git Statuses](resources/prompt-shots/git-statuses.png)
The indicator at the right changes when you're in a git repo, showing if there are uncommitted
or unpushed changes. (Mercurial code is there but disabled because it's slow. 😫)

![Status Messages](resources/prompt-shots/messages.png)
The prompt can also expand to give status messages about detached tmux sessions, long execution
times, and error codes. 
