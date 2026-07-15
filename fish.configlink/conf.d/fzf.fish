# fzf shell integration: Ctrl-R history, Ctrl-T files, Alt-C cd, plus
#   **-tab completion. Generated straight from the fzf binary (0.48+), which
#   replaces the old symlink into the Homebrew keg's key-bindings.fish -
#   that hardcoded the Intel prefix (/usr/local) and broke silently on
#   Apple Silicon. The generated script defines and invokes
#   fzf_key_bindings itself, so nothing else needs to call it.
if status is-interactive; and type -q fzf
    fzf --fish | source
end
