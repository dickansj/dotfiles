#!/bin/bash

# modified from https://github.com/holman/dotfiles/blob/master/script/bootstrap


# make sure we're in the right place...
cd "$(dirname "$0")"
DOTFILES_ROOT=$(pwd -P)

source ./utility/utility_functions.sh

install_dotfiles () {
  local overwrite_all=false backup_all=false skip_all=false

  for src in $(find -H "$DOTFILES_ROOT" -maxdepth 2 -name '*.symlink' -not -path '*.git*')
  do
    dst="$HOME/.$(basename "${src%.*}")"
    link_file "$src" "$dst"
  done
}

install_dotfiles

install_homefiles () {
  local overwrite_all=false backup_all=false skip_all=false

  for src in $(find -H "$DOTFILES_ROOT" -maxdepth 2 -name '*.homelink' -not -path '*.git*')
  do
    dst="$HOME/$(basename "${src%.*}")"
    link_file "$src" "$dst"
  done
}

install_homefiles


install_configfiles () {
  local overwrite_all=false backup_all=false skip_all=false

  mkdir -p -m 700 $HOME/.config
  for src in $(find -H "$DOTFILES_ROOT" -maxdepth 2 -name '*.configlink' -not -path '*.git*')
  do
    dst="$HOME/.config/$(basename "${src%.*}")"
    link_file "$src" "$dst"
  done
}

install_configfiles


install_launchagents() {
  local overwrite_all=false backup_all=false skip_all=false

  mkdir -p $HOME/Library/LaunchAgents
  for src in $(find -H "$DOTFILES_ROOT/osx-launchagents" -maxdepth 2 -name '*.plist' -not -path '*.git*')
  do
    dst="$HOME/Library/LaunchAgents/$(basename "$src")"
    link_file "$src" "$dst"
  done
}
if [[ $OSTYPE == darwin* ]]; then
  install_launchagents
fi


install_dictionaries() {
  local overwrite_all=false backup_all=false skip_all=false

  # macOS's shared system spell-check dictionary (BBEdit and most other
  #   Cocoa apps defer to this rather than keeping their own word list)
  mkdir -p "$HOME/Library/Spelling"
  link_file "$DOTFILES_ROOT/osx-dictionaries/LocalDictionary" "$HOME/Library/Spelling/LocalDictionary"

  # Word keeps its own separate custom dictionary that can't be symlinked
  #   (see osx-dictionaries/README.md for why) - sync it from the canonical
  #   list above instead. Safe to re-run: it merges rather than overwrites,
  #   so it never clobbers words learned in Word since the last sync.
  "$DOTFILES_ROOT/bin.homelink/syncdict"
}
if [[ $OSTYPE == darwin* ]]; then
  install_dictionaries
fi
