#!/usr/bin/env bash

## Outputs installed Setapp app list
## Hazel runs as an embedded script ("Setapp Installed") whenever a new app is added
ls /Applications/Setapp | grep -E '\.app$' > ~/.dotfiles/setapp-install.txt