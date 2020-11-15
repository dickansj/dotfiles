#!/bin/bash

## Outputs installed Setapp app list
## Called by Hazel ("Setapp Installed") whenever a new app is added
ls /Applications/Setapp | egrep '\.app$' > ~/.dotfiles/setapp-install.txt