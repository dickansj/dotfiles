
if [[ -r /etc/zprofile ]]; then
  source /etc/zprofile
elif [[ -r /etc/zsh/zprofile ]]; then
  source /etc/zsh/zprofile
else
  echo "Couldn't load a base zprofile..."
fi

local -a myPath=()

## Go
if type go > /dev/null 2>&1; then
  export GOPATH="$HOME/go"
  myPath+=("$GOPATH/bin")
fi

## Various paths to add if certain things are installed
local -a addIfExists=(
  # Rust
  $HOME/.cargo/bin

  # itch.io
  $HOME/Library/Application\ Support/itch/bin
)
for maybePath in "${addIfExists[@]}"; do
  if [[ -d $maybePath ]]; then
    myPath+=("$maybePath")
  fi
done

## Installed stuff (mostly from Homebrew)
# myPath+=(/usr/local/bin)
myPath+=(/usr/local/sbin)

path=($myPath $path)


myPath=()

## Ruby, checking for rbenv first
if [[ -a /usr/local/bin/rbenv ]]; then
  eval "$(/usr/local/bin/rbenv init --no-rehash -)"
  (/usr/local/bin/rbenv rehash &) 2> /dev/null
elif [[ -a $HOME/.rbenv/bin/rbenv ]]; then
  eval "$($HOME/.rbenv/bin/rbenv init --no-rehash -)"
  ($HOME/.rbenv/bin/rbenv rehash &) 2> /dev/null
elif type ruby > /dev/null 2>&1; then
  myPath+=("$(ruby -rubygems -e 'puts Gem.user_dir')/bin")
fi

## Node.js, checking for nodenv first
if [[ -a /usr/local/bin/nodenv ]]; then
  eval "$(/usr/local/bin/nodenv init --no-rehash -)"
  (/usr/local/bin/nodenv rehash &) 2> /dev/null
elif [[ -a $HOME/.nodenv/bin/nodenv ]]; then
  eval "$($HOME/.nodenv/bin/nodenv init --no-rehash -)"
  ($HOME/.nodenv/bin/nodenv rehash &) 2> /dev/null
elif type npm > /dev/null 2>&1; then
  myPath+=("$(npm bin -g)")
fi

## Python, checking for pyenv first
if [[ -a /usr/local/bin/pyenv ]]; then
  eval "$(/usr/local/bin/pyenv init --no-rehash -)"
  (/usr/local/bin/pyenv rehash &) 2> /dev/null
elif [[ -a $HOME/.pyenv/bin/pyenv ]]; then
  eval "$($HOME/.pyenv/bin/pyenv init --no-rehash -)"
  ($HOME/.pyenv/bin/pyenv rehash &) 2> /dev/null
elif type python > /dev/null 2>&1; then
  myPath+=("$(python -m site --user-base)/bin")
fi

path=($myPath $path)


## Any custom programs come first
path=($HOME/bin $path)
