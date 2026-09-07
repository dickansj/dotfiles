# fzf shell integration: Ctrl-R history, Ctrl-T files, Alt-C cd, plus
#   **-tab completion. Generated straight from the fzf binary (0.48+), which
#   replaces the old symlink into the Homebrew keg's key-bindings.fish -
#   that hardcoded the Intel prefix (/usr/local) and broke silently on
#   Apple Silicon. The generated script defines and invokes
#   fzf_key_bindings itself, so nothing else needs to call it.
#
# `fzf --fish` alone costs ~25ms in `fish --profile-startup` testing (fzf
#   regenerating its whole integration script from scratch on every shell
#   start), so the generated script is cached in fish's own cache dir and
#   only regenerated when it's older than the fzf binary itself - i.e.
#   after fzf gets upgraded - rather than shelled out to every time.
if status is-interactive; and type -q fzf
    set --local fzfCache $__fish_cache_dir/fzf-init.fish
    set --local fzfBin (command -v fzf)
    if not test -f $fzfCache; or test $fzfBin -nt $fzfCache
        fzf --fish > $fzfCache
    end
    source $fzfCache
end
