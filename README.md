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
    keep Word's custom dictionary synced with it automatically via a
    LaunchAgent (`syncdict`/`syncdict-agent` — see
    `osx-dictionaries/README.md`). **Manual one-time step this doesn't
    automate**: grant Full Disk Access to
    `~/.dotfiles/bin.homelink/syncdict-agent` in System Settings → Privacy
    & Security, or the automatic sync fails silently (running `syncdict`
    by hand still works regardless)
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


## Tests
`tests/run_all.sh` runs a regression suite (script lint, a sandboxed
`install_symlinks.sh` run, fish config smoke tests, dictionary-sync
round-trip); CI runs it on every push on both Ubuntu and macOS, alongside a
Brewfile audit against the live Homebrew/App Store catalogs.

## Ejecting external volumes
`bin.homelink/eject-prep` kills the Finder/QuickLook thumbnail-generation
processes that sometimes hold external volumes open, causing spurious "disk
in use" failures when trying to eject
([reference](https://github.com/Marginal/QuickLookVideo/issues/188)) — pulled
in from upstream, not something written here originally.

Actual ejecting is handled by [Mountio](https://mountio.app), which has no
scripting, hotkey, or automation API of any kind — it's a pure point-and-click
menu bar utility. So the two are chained together with a Keyboard Maestro
macro (not tracked in this repo — Keyboard Maestro stores macros in its own
library, not as files) bound to `Shift+Option+Cmd+E`:

1. **Execute Shell Script**: `~/bin/eject-prep`
2. **Execute AppleScript**, targeting Mountio's status item by its
   accessibility role/hierarchy rather than screen pixels — deliberately not
   image matching, which broke under badge-count/Retina/light-dark changes:
   ```applescript
   tell application "System Events"
       tell process "Mountio"
           click menu bar item 1 of menu bar 1
           delay 0.3
           click menu item "Unmount all" of menu 1 of menu bar item 1 of menu bar 1
       end tell
   end tell
   ```

Requires granting **Accessibility** access (System Settings → Privacy &
Security → Accessibility) to **Keyboard Maestro Engine** specifically — the
background process that actually runs macros, a different process identity
than the Keyboard Maestro editor app itself.
