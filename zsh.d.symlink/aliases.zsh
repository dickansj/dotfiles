alias reload!='. ~/.zshrc'

if $(gls &>/dev/null); then
  alias ls="gls -F --color"
  alias ll="gls -lh --color"
  alias la="gls -FA --color"
  alias lla="gls -lhA --color"
  alias lsp="gls -lhA --color"
else
  alias ls="ls -F --color"
  alias ll="ls -lh --color"
  alias la="ls -FA --color"
  alias lla="ls -lhA --color"
  alias lsp="ls -lhA --color"
fi

alias mkdir="mkdir -p"

# Mac-specific aliases
if [[ $OSTYPE == darwin* ]]; then
  if type hub > /dev/null; then
    alias git="hub"
  fi
fi

 alias ..='cd ../'             # Go up 1 dir level
 alias ...='cd ../../'         # Go up 2 dir levels
 alias .3='cd ../../../'       # Go up 3 dir levels

# Homebrew shortcut alias
# Consider doing environment upgrade with envup
# https://gist.github.com/indiesquidge/ec010eca3ffa254788c2
alias brewup='brew update; brew upgrade; brew cleanup; brew doctor'
 
# thefuck error correction
# https://github.com/nvbn/thefuck
eval $(thefuck --alias fuck)