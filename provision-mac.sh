#!/usr/bin/env bash

# Note: This script is designed to only be run once, on a completely
#       fresh Mac. If you've already done some setup, it might break
#       things. It's not idempotent -- not even a little.
#       If you're stumbling across this from elsewhere, don't blindly
#       run it without understanding what it does.

# Take APFS snapshot for quick rollback just in case
# If you need to rollback, use: Recovery Mode > Recover from Time Machine > [Select Startup Drive] > [Select Snapshot]."
tmutil snapshot

function timerData() {
  echo $1: $SECONDS >> provision_timing.txt
}

# die on errors
set -e

# set up input
exec </dev/tty >/dev/tty

# make sure we're in the right place...
cd "$(dirname "$0")"
DOTFILES_ROOT=$(pwd -P)

date >> provision_timing.txt
timerData "START"

# copy dotfiles
./install_symlinks.sh

# ssh config
mkdir -p ~/.ssh
cp resources/ssh_config.base ~/.ssh/config

# Ask for the administrator password
echo "Now we need sudo access to install homebrew, some GUI apps, and change the shell."
sudo -v
still_need_sudo=1
while still_need_sudo; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

timerData "PRE-BREW"

# install homebrew
export HOMEBREW_NO_ANALYTICS=1
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Turning off quarantine for casks; assuming I trust any apps that
#   made it into the Brewfile. *slightly* perilous, though.
HOMEBREW_CASK_OPTS="--no-quarantine" \
  brew bundle install --no-lock --file=$DOTFILES_ROOT/install_lists/Brewfile

# set fish as user shell
targetShell="/usr/local/bin/fish"
echo $targetShell | sudo tee -a /etc/shells
sudo chsh -s $targetShell $USER

# homebrew doesn't link OpenJDK by default; do it while we still have sudo
sudo ln -sfn /usr/local/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk

# Reveal IP address, hostname, OS version, etc. when clicking the clock
# in the login window
sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName

# no more sudo needed!
still_need_sudo=0
sudo -k

# clean up after homebrew
brew cleanup -s
rm -rf $(brew --cache)
export HOMEBREW_NO_AUTO_UPDATE=0

timerData "POST-BREW"

# make sure we're running in a local git working copy
#  (this hooks us in if we were set up from the bootstrap script)
if [[ ! -d .git ]]; then
  (
    # don't look at the ~/.gitconfig
    unset HOME

    git init --initial-branch=main
    git remote add origin https://github.com/dickansj/dotfiles.git
    git fetch
    git reset origin/main
    git branch --set-upstream-to=origin/main main
    git checkout .
  )
fi
# swap to ssh; credentials can get added later
git remote set-url origin git@github.com:dickansj/dotfiles.git

# Projects folder is where most code stuff lives; link this there, too,
#  because otherwise I'll forget where it is
if [[ ! -d ~/Projects/dotfiles ]]; then
  mkdir -p ~/Projects
  ln -s $DOTFILES_ROOT ~/Projects/dotfiles
fi

# any vim bundles
(
  # forget about the gitconfig for now
  unset HOME
  vim +PluginInstall +qall
)


# copying version check from envup
env_remVer() {
    $1 install -l 2>&1 \
        | grep -vE "\s*[a-zA-Z-]" \
        | sort -V \
        | grep "^\s*$2" \
        | tail -1 \
        | xargs
}

# python setup
git clone https://github.com/pyenv/pyenv.git $HOME/.pyenv
git clone https://github.com/pyenv/pyenv-update.git $HOME/.pyenv/plugins/pyenv-update
pyPath="$HOME/.pyenv/shims"
pyenv="$HOME/.pyenv/bin/pyenv"

py3version=$(env_remVer $pyenv 3)
LDFLAGS="-L/usr/local/opt/zlib/lib -L/usr/local/opt/sqlite/lib" \
  CPPFLAGS="-I/usr/local/opt/zlib/include -I/usr/local/opt/sqlite/include" \
  $pyenv install $py3version
$pyenv global $py3version
$pyenv rehash
$pyPath/pip3 install --upgrade pip
$pyPath/pip3 install -r install_lists/python3-dev-packages.txt
$pyenv rehash

py2version=$(env_remVer $pyenv 2)
LDFLAGS="-L/usr/local/opt/zlib/lib -L/usr/local/opt/sqlite/lib" \
  CPPFLAGS="-I/usr/local/opt/zlib/include -I/usr/local/opt/sqlite/include" \
  $pyenv install $py2version
$pyenv global $py3version $py2version
$pyenv rehash
$pyPath/pip2 install --upgrade pip
$pyPath/pip2 install -r install_lists/python2-dev-packages.txt
$pyenv rehash

$pyenv install miniconda3-latest
$pyenv global $py3version $py2version miniconda3-latest
$pyPath/conda update --all -y
$pyPath/conda install anaconda-navigator -y

eval "$($pyenv init -)"

curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | $pyPath/python
$HOME/.poetry/bin/poetry config virtualenvs.in-project true

timerData "POST-PYTHON"

# ruby setup
rbPath="$HOME/.rbenv/shims"
rbenv="/usr/local/bin/rbenv"
rbversion=$(env_remVer $rbenv 3)
RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)" \
  $rbenv install $rbversion
$rbenv global $rbversion
eval "$($rbenv init -)"

$rbPath/gem update --system
yes | $rbPath/gem update
yes | $rbPath/gem install bundler
$rbPath/gem cleanup

timerData "POST-RUBY"

# node setup
nodePath="$HOME/.nodenv/shims"
nodenv="/usr/local/bin/nodenv"
git clone https://github.com/nodenv/node-build-update-defs.git "$(nodenv root)"/plugins/node-build-update-defs
$nodenv update-version-defs
nodeversion=$(env_remVer $nodenv "\d*[02468]\.")
$nodenv install $nodeversion

$nodenv global $nodeversion
eval "$($nodenv init -)"

$nodePath/npm install -g npm
$nodePath/npm install -g $(cat install_lists/node-packages.txt)

timerData "POST-NODE"

# rust setup
curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path

timerData "POST-RUST"

# set up Terminal
cp ./resources/FiraMod/* $HOME/Library/Fonts/

osascript 2>/dev/null <<EOD
  tell application "Terminal"
    local allOpenedWindows
    local initialOpenedWindows
    local windowID

    set initialOpenedWindows to id of every window

    do shell script "open './resources/SJML.terminal'"
    delay 1
    set default settings to settings set "SJML"

    delay 5
    set allOpenedWindows to id of every window
    repeat with windowID in allOpenedWindows
      if initialOpenedWindows does not contain windowID then
        close (every window whose id is windowID)
      else
        set current settings of tabs of (every window whose id is windowID) to settings set "SJML"
      end if
    end repeat
  end tell
EOD

# let QuickLook stuff run without Gatekeeper complaining
xattr -cr ~/Library/QuickLook/*
qlmanage -r
qlmanage -r cache


## We'll see how these go with Big Sur...

# this will pop a permissions window, but no way around it
#   (this is a good thing to have security around, I will agree)
defaultbrowser firefoxdeveloperedition

# Turn off unneeded menu bar items
defaults -currentHost write dontAutoLoad -array-add "/System/Library/CoreServices/Menu Extras/Displays.menu"
defaults -currentHost write dontAutoLoad -array-add "/System/Library/CoreServices/Menu Extras/Volume.menu"
defaults -currentHost write dontAutoLoad -array-add "/System/Library/CoreServices/Menu Extras/User.menu"

# Clock formatting: with seconds, 12 hr AM/PM, no flashing separators
defaults write com.apple.menuextra.clock DateFormat -string "h:mm:ss a"
defaults write com.apple.menuextra.clock FlashDateSeparators -bool false

# Always show scrollbars
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"

# Globally remove proxy icon hover delay
# (introduced in Big Sur)
defaults write -g NSToolbarTitleViewRolloverDelay -float 0

# Text selection in QuickLook
defaults write com.apple.finder QLEnableTextSelection -bool true

# Enable full keyboard access for all controls
# (e.g. enable Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Set language and text formats
# Note: if you’re in the US, replace `EUR` with `USD`, `Centimeters` with
# `Inches`, `en_GB` with `en_US`, and `true` with `false`.
defaults write NSGlobalDomain AppleLanguages -array "en" "ar"
defaults write NSGlobalDomain AppleLocale -string "en_US@currency=USD"
defaults write NSGlobalDomain AppleMeasurementUnits -string "Inches"
defaults write NSGlobalDomain AppleMetricUnits -bool false

# Don't open folders in tabs
defaults write com.apple.finder FinderSpawnTab -bool false

# Set ~ as the default location for new Finder windows
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"

# Show icons for external hard drives, servers, and removable media on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Show the ~/Library folder
xattr -d com.apple.FinderInfo ~/Library
chflags nohidden ~/Library

# Eliminate Finder proxy icon hover delay in Big Sur
# These are the kinds of things that keep me using a Finder alternative most of the time...
defaults write com.apple.Finder NSToolbarTitleViewRolloverDelay -float 0

# Expand save and print panels by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Disable “natural” (Lion-style) scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# disable tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -int 0

# enable two-fingered right-click
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -int 1

# disable three-fingered tap for lookup
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0

# enable three-finger swipe through pages
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 1

# enable four-finger swipe through fullscreen apps
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 2

# enable four-finger-swipes for Mission Control and App Expose
defaults write com.apple.dock showMissionControlGestureEnabled -bool true
defaults write com.apple.dock showAppExposeGestureEnabled -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2

# enable four-finger spread to show desktop
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerPinchGesture -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadFiveFingerPinchGesture -int 2
defaults write com.apple.dock showDesktopGestureEnabled -bool true

# disable Launchpad gesture
defaults write com.apple.dock showLaunchpadGestureEnabled -bool false

# Enable Control-Scroll to zoom screen
defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
defaults write com.apple.universalaccess HIDScrollZoomModifierMask -int 262144

# Require password 5 minutes after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -float 300.0

# Set screen saver to Drift (blue) with visible clock
defaults -currentHost write com.apple.screensaver modulePath -string "/System/Library/Screen Savers/Drift.saver"
defaults -currentHost write com.apple.screensaver moduleName -string "Drift"
defaults -currentHost write com.apple.screensaver moduleDict -dict moduleName "Drift" path "/System/Library/Screen Savers/Drift.saver" type 0
defaults -currentHost write com.apple.ScreenSaver.Drift ColorScheme -string "blues"
defaults -currentHost write com.apple.screensaver showClock -bool true

# Show language menu in the top right corner of the boot screen
sudo defaults write /Library/Preferences/com.apple.loginwindow showInputMenu -bool true

# Show the full URL in the address bar (note: this still hides the scheme)
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# Remove useless icons from Safari’s bookmarks bar
defaults write com.apple.Safari ProxiesInBookmarksBar "()"

# Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# Add a context menu item for showing the Web Inspector in web views
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# Block pop-up windows
defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool false

# Enable “Do Not Track”
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true

# Update extensions automatically
defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

# Chrome - Disable the all too sensitive backswipe on trackpads
defaults write com.google.Chrome AppleEnableSwipeNavigateWithScrolls -bool false
defaults write com.google.Chrome.canary AppleEnableSwipeNavigateWithScrolls -bool false

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# Remove font smoothing
# https://www.fontsmoothingadjuster.com/
# https://tonsky.me/blog/monitors/ for setting integer scaling
defaults -currentHost write -g AppleFontSmoothing -int 0

# Disable Dashboard
defaults write com.apple.dashboard mcx-disabled -bool true

# Set the icon size of Dock items to biggest
# defaults write com.apple.dock tilesize -int 128

# Automatically hide and show the Dock
defaults write com.apple.dock autohide -bool true

# Eliminate Dock autohide-delay
# https://swissmacuser.ch/show-macos-dock-instantly-without-delay/
# For Apple Silicon: defaults write com.apple.dock autohide-delay -float 0 && defaults write com.apple.dock autohide-time-modifier -float 0.4
# For Intel:
defaults write com.apple.dock autohide-delay -float 0

# Turn off Dock magnification
defaults write com.apple.dock magnification -bool false

# Don’t show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# Allow slow-motion minimize effects when holding down shift (relic from old OS X :D)
defaults write com.apple.dock slow-motion-allowed -bool true

# Hot corner, bottom-right: Start screen saver
defaults write com.apple.dock wvous-br-corner -int 5
defaults write com.apple.dock wvous-br-modifier -int 0

# Add the keyboard shortcut ⌘ + Enter to send an email in Mail.app
defaults write com.apple.mail NSUserKeyEquivalents -dict-add "Send" "@\U21a9"

# Enable the automatic update check
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Check for software updates daily, not just once per week
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Do not automatically update apps
defaults write com.apple.commerce AutoUpdate -bool false

# Install System data files & security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

# Set archive utility to not open a new window when it extracts things
defaults write com.apple.archiveutility dearchive-reveal-after -int 0

## set up Dock

# move to bottom
defaults write com.apple.dock orientation bottom

# NB: paths to system applications won't work in Big Sur;
# now require "/System/Applications/$app.app";
# also includes some manually installed apps;
# remember to update this list when getting a new machine
dockutil --remove all --no-restart
declare -a dockList=(\
  /System/Library/CoreServices/Finder\
  /Applications/Setapp/Path\ Finder\
  /System/Applications/System\ Preferences\
  /Applications/1Password\ 7\
  /Applications/Pastebot\
  /Applications/Setapp/Session\
  /Applications/Anki\
  /System/Applications/Messages\
  /System/Applications/Facetime\
  /Applications/WhatsApp\
  /System/Applications/Music\
  /System/Applications/Photos\
  /Applications/Fantastical\
  /Applications/Cardhop\
  /Applications/CARROTweather\
  /Applications/Firefox\ Developer\ Edition\
  /Applications/Firefox\
  /System/Applications/Safari\
  /Applications/Airmail\
  /Applications/Setapp/News\ Explorer\
  /Applications/Twitterific\
  /Applications/Discord\
  /Applications/PDFpenPro\
  /Applications/Setapp/TaskPaper\
  /Applications/Drafts\
  /Applications/Marked\ 2\
  /Applications/BBEdit\
  /Applications/Visual\ Studio\ Code\
  /Applications/Tower\
  /System/Applications/Utilities/Terminal\
  /Applications/RStudio\
  /Applications/PCalc\
  /Applications/Setapp\
  /System/Applications/App\ Store\
)
for app in "${dockList[@]}"; do
  dockutil --add "$app" --no-restart
done
dockutil --add "~/Downloads" --section others --view grid --display stack --no-restart

# killall complains if there's no instances running, so ignore it
#   (and don't error)
killall cfprefsd 2> /dev/null || true
killall SystemUIServer 2> /dev/null || true
killall Finder 2> /dev/null || true
killall Dock 2> /dev/null || true
killall Mail 2> /dev/null || true
killall Safari 2> /dev/null || true
killall Google\ Chrome 2> /dev/null || true

timerData "POST-GUI"



timerData "DONE"

cd ~
echo
echo
echo "And that's it! You're good to go, but restarting might be wise."
