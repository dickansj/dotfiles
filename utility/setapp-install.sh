#!/usr/bin/env bash

## Outputs installed Setapp app list
## Hazel runs as an embedded script ("Setapp Installed") whenever a new app
##   is added - NB Hazel embeds its own copy of this one-liner, so any
##   change here has to be repeated inside the Hazel rule by hand
ls /Applications/Setapp | grep -E '\.app$' > ~/.dotfiles/install_lists/setapp-install.txt