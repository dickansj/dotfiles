My dotfiles, to get a computer running the way I like it. I have built upon the upstream [sjml/dotfiles](https://github.com/sjml/dotfiles) with some customizations for my own workflows, though the underlying setup is predominantly derived from his work there.

## Installation
To bootstrap onto a fresh *nix computer (that may not have git, like Macs out of the box): 
```shell-script
curl -fsSL https://raw.githubusercontent.com/dickansj/dotfiles/main/bootstrap.sh | bash

# Or original
# curl -fsSL https://raw.githubusercontent.com/sjml/dotfiles/main/bootstrap.sh | bash
```

Or on Windows, from an Administrator PowerShell:
```powershell
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/dickansj/dotfiles/main/bootstrap.ps1'))
```

## What it does
Running `provision-mac.sh` on a fresh Mac will:
  * Take an APFS snapshot first, for quick rollback if anything goes sideways
  * Take everything in this directory that ends with `.symlink` and make a
    symbolic link to it in the current user's home directory, minus the 
    `.symlink` and prepended with a `.`
    * Similarly, anything with `.configlink` gets linked into `.config`
      without a prepended `.`
    * `.homelink` gets the same treatment, but into `~`
  * Symlink files in `osx-launchagents` to `~/Library/LaunchAgents`
  * Symlink the shared macOS spelling dictionary (`osx-dictionaries/`) and
    sync Word's custom dictionary from it (via `syncdict` — see
    `osx-dictionaries/README.md`)
  * Copy (not symlink — so private host entries stay out of the repo)
    `resources/ssh_config.base` to `~/.ssh/config`
  * Install [homebrew](http://brew.sh) with analytics turned off
  * Validate `install_lists/Brewfile` against the live Homebrew/App Store
    catalogs, and check that you're signed into the Mac App Store, before
    installing anything
  * Install all the brew packages, GUI apps, and fonts listed in `install_lists/Brewfile`. This includes Mac App Store apps specified under the mas section there.
  * Change the default shell to [fish](https://fishshell.com/)
  * Allow Touch ID to authorize `sudo` in the terminal
  * Set Homebrew's version of OpenJDK to be used instead of system's
  * Sets up the directory to be a proper git repository if it was pulled during a bootstrap
  * Make a `~/Projects` directory and symlink the dotfiles there
  * Install a set of vim bundles, managed by [Vundle](https://github.com/VundleVim/Vundle.vim)
  * Configure a default stable [Rust](https://www.rust-lang.org/) toolchain via [rustup](https://rust-lang.github.io/rustup/) (rustup itself comes from the Brewfile)
  * Set up appearance of Terminal.app
  * Set default file-type associations (PDF, images, markdown, etc.) via `duti`
  * Set default browser to Firefox Developer Edition
  * Various and sundry macOS GUI settings (Finder behaviors, Trackpad settings, etc.)
  * Set up the Dock

The `provision-linux.sh` is much simpler because I don't have root on most Linux
machines I use, and tend to not have them quite as customized. All it does:
  * Symlink the designated dotfiles
  * Symlink this to ~/Projects/dotfiles
  * Install the vim bundles
  * Install pyenv, but nothing else

The Windows version (`provision-windows.ps1`) is pretty sparse. Used to use
[Chocolatey](http://chocolatey.org/), but want to shift it to use [WinGet](https://github.com/microsoft/winget-cli) before I set up another Windows machine. 

