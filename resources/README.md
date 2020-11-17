This directory contains binary resources that I take with me everywhere.

## pandas
I've been using this image as my user icon since college. No reason to change
it yet. This is effectively as much a part of my dotfiles as my `$EDITOR`
definition. 

## ssh_config.base
The file that gets appended to the end of my `~/.ssh/config` after a new key is
added to it, so that servers without a corresponding key just ask for a password.

## MLA Template
Overall I like [MLA style format](https://style.mla.org/mla-format/), but they say 
the bibliography should also be double-spaced, which I think is just indulgent. So 
the `MLA_8_Tight_Bibliography.csl` file is a [Citation Style Language](https://citationstyles.org/) 
specification, forked from the [official Zotero one](http://www.zotero.org/styles/modern-language-association), with a less expansive bibliography style.

## Office Templates
Templates for MS Office. Set the location in Word's Preferences -> File Locations -> User Templates.

## Xcode Templates
Templates for Xcode. `ln -s ~/.dotfiles/resources/Xcode\ Templates ~/Library/Developer/Xcode/Templates/Custom`

## rstudio-prefs.json
R Studio user preferences.
```
mkdir -p ~/.config/rstudio
ln -s ~/.dotfiles/resources/rstudio-prefs.json ~/.config/rstudio
```

## Path Finder Preferences
I use Path Finder as a Finder (partial) alternative. Path Finder preference export is [not supported](https://support.cocoatech.com/discussions/problems/135101-how-to-save-all-path-finder-application-settings-for-use-on-my-other-mac), linking support files across versions has sometimes caused issues, and some functionality is likely to change under Big Sur . . . so I am maintaining a PDF of the preferences I am setting through the GUI settings.
