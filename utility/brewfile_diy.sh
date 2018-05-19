#!/bin/bash

cd "$(dirname "$0")"

# keep up our permissions until we've gotten through everything
still_need_sudo=1
while still_need_sudo; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

declare -a packages=()
declare -a casks=()
declare -a taps=()
declare -a mass=()

while read command; do
  if [[ ${#command} -eq 0 ]]; then
    continue
  elif [[ $command =~ ^[[:space:]]*# ]]; then
    continue
  elif [[ $command =~ ^[[:space:]]*tap[[:space:]]*\' ]]; then
    tap=$(echo $command | sed -E "s/tap[[:space:]]+'([^']*)'/\1/")
    taps+=($tap)
  elif [[ $command =~ ^[[:space:]]*brew[[:space:]]*\' ]]; then
    pkg=$(echo $command | sed -E "s/brew[[:space:]]+'([^']*)'/\1/")
    if [[ $pkg =~ ,[[:space:]]+args: ]]; then
      pkgName=$(echo $pkg | sed -E "s/^([^,]*).*/\1/")
      pkgArgs=$(echo $pkg | sed -E "s/.*args:[[:space:]]*\[(.*)\]/\1/")
      pkg=$pkgName
      pkgArgsArr=$(echo $pkgArgs | tr "," "\n")
      for arg in $pkgArgsArr; do
        pkg+=$(echo $arg | sed -E "s/^\"(.*)\"$/ --\1/")
      done
    fi
    packages+=("$pkg")
  elif [[ $command =~ ^[[:space:]]*cask[[:space:]]*\' ]]; then
    cask=$(echo $command | sed -E "s/cask[[:space:]]+'([^']*)'/\1/")
    casks+=($cask)
  elif [[ $command =~ ^[[:space:]]*mas[[:space:]]*\' ]]; then
    # echo $command
    appName=$(echo $command | sed -E "s/mas[[:space:]]+'([^']*)'.*/\1/")
    appId=$(echo $command | sed -E "s/.*id:[[:space:]]+([0-9]*)/\1/")
    mass+=($appId)
  fi
done <../install_lists/Brewfile

# I wanna tap everything
for tap in "${taps[@]}"; do
  /usr/local/bin/brew tap $tap
done

# log in to the Mac App Store if necessary
if [[ ${#mass[@]} -gt 0 ]]; then
  /usr/local/bin/brew install mas

  # just bouncing out to make sure we sign in with the correct ID here
  /usr/local/bin/mas signout
  echo "Signing in to Mac App Store via GUI..."
  /usr/local/bin/mas signin --dialog
fi

# get the casks first
mkdir -p ~/Library/Caches/Homebrew/Cask
for cask in "${casks[@]}"; do
  /usr/local/bin/brew cask fetch $cask
done

# now actually install
for cask in "${casks[@]}"; do
  /usr/local/bin/brew cask install $cask
done

# no more sudo needed!
still_need_sudo=0
sudo -k

# app store installations
for app in "${mass[@]}"; do
  /usr/local/bin/mas install $app
done

# finally, our beloved CLI things, which Simply Work™
for package in "${packages[@]}"; do
  /usr/local/bin/brew install $package
done
