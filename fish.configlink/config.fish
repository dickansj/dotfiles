set --local FISHDIR ~/.config/fish

source $FISHDIR/env.fish

## put any machine-specific environment variables in ~/.local/config/config.fish
##   (NB that file is not in source control)
if test -e "$HOME/.local/config/config.fish";
  source $HOME/.local/config/config.fish
end

## load up aliases
source $FISHDIR/aliases.fish

# thefuck error correction
# https://github.com/nvbn/thefuck
thefuck --alias | source

## if we start a tmux session from a virtualenved environment
if test -n "$VIRTUAL_ENV"
  source "$VIRTUAL_ENV/bin/activate.fish"
end

## settings for the git status prompt
set __fish_git_prompt_show_informative_status true
set __fish_git_prompt_showcolorhints true
set __fish_git_prompt_char_dirtystate '*'
set __fish_git_prompt_color_cleanstate 777777
set __fish_git_prompt_showuntrackedfiles true
set __fish_git_prompt_showstashstate true

## turn off greeting
set fish_greeting

## let the terminal emulator handle the titling
function fish_title
end

## brew-wrap for homebrew brew-file package
## brew-file maintains install list separate from dotfile list and is handy for keeping multiple Macs in sync wrt apps
## wraps the original `brew` command for an automatic update of Brewfile when you run `brew install` or `brew uninstall`
## https://homebrew-file.readthedocs.io/en/latest/installation.html
if test -f (brew --prefix)/etc/brew-wrap.fish
  source (brew --prefix)/etc/brew-wrap.fish
end

## set up direnv
direnv hook fish | source

# Load DeepL translation functions
set utility_dir ~/.dotfiles/utility/functions

# Add run-translate
if test -f $utility_dir/run-translate.fish
    source $utility_dir/run-translate.fish
end
