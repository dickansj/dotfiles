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
#   only regenerated when the fzf binary itself has changed, rather than
#   shelled out to every time.
if status is-interactive; and type -q fzf
    set --local fzfCache $__fish_cache_dir/fzf-init.fish
    set --local fzfCacheMarker $__fish_cache_dir/fzf-init.bin-mtime
    set --local fzfBin (command -v fzf)
    # regenerate on any mtime *inequality*, not just "newer than": a
    #   Homebrew bottle reinstall/downgrade can preserve a build-time mtime
    #   older than the cache, which -nt alone would miss and keep serving
    #   stale integration silently. $fzfCacheMarker's mtime is stamped to
    #   match $fzfBin's every time the cache is (re)built, so two -nt/-ot
    #   comparisons - real stat syscalls via fish's `test` builtin, not the
    #   external `stat` command, whose flags differ BSD vs. GNU (see
    #   tests/run_all.sh notes) - are enough to detect any change without
    #   another subprocess.
    if not test -f $fzfCache
    or test $fzfBin -nt $fzfCacheMarker
    or test $fzfBin -ot $fzfCacheMarker
        fzf --fish > $fzfCache
        touch -r $fzfBin $fzfCacheMarker
    end
    source $fzfCache
end
