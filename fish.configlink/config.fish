set --local FISHDIR ~/.config/fish

source $FISHDIR/env.fish

## put any machine-specific environment variables in ~/.local/config/config.fish
##   (NB that file is not in source control)
if test -e "$HOME/.local/config/config.fish";
  source $HOME/.local/config/config.fish
end

## load up aliases
source $FISHDIR/aliases.fish

# pay-respects error correction (thefuck replacement, written in Rust -
#   no per-shell Python startup cost)
# https://github.com/iffse/pay-respects
# usage: after a command fails, type `f` to get a corrected suggestion
#   (confirm to run it); Ctrl-X Ctrl-X rewrites the current command line
#   inline instead
# (type -q guards here and below: this config also runs on Linux boxes
#   that don't have every tool installed, and an unguarded `missing-cmd |
#   source` errors at every shell start)
if type -q pay-respects
  pay-respects fish --alias | source
end

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
## (checking both known prefixes directly, instead of `(brew --prefix)`,
##  avoids spawning Homebrew's own Ruby interpreter twice on every shell
##  start just to resolve a value that's static per machine - ~36ms
##  combined in `fish --profile-startup` testing. /opt/homebrew is checked
##  first deliberately: if a Rosetta Homebrew ever exists at /usr/local
##  alongside the native arm64 one, arm64 should win - same precedence
##  provision-mac.sh's `uname -m` branch would give it. If those two ever
##  disagree on which prefix is "the" one, that's a bug to fix here, not a
##  reason to add a third source of truth.)
if type -q brew
  for brewPrefix in /opt/homebrew /usr/local
    if test -f $brewPrefix/etc/brew-wrap.fish
      source $brewPrefix/etc/brew-wrap.fish
      break
    end
  end
end

## set up direnv
if type -q direnv
  direnv hook fish | source
end
