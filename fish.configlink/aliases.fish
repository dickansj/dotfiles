
if type -q gls
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
end

alias mkdir="mkdir -p"
alias vim="nvim"

alias ..='cd ../'             # Go up 1 dir level
alias ...='cd ../../'         # Go up 2 dir levels
alias .3='cd ../../../'       # Go up 3 dir levels

# platform-specific aliases
switch (uname)
  case Darwin
    alias c="code ."
    alias edot="code ~/.dotfiles"

    function o;open -a $argv;end
    complete -c o -a (basename -s .app /Applications{,/Utilities}/*.app|awk '{printf "\"%s\" ", $0 }')
end

