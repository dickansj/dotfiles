#!/usr/bin/env bash

# Static checks over every script and convention in the repo. Each check
#   here guards against a bug class that has actually happened - see git
#   history and CLAUDE.md for the war stories.

set -u
cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd -P)"

fails=0
err() {
  echo "  ❌ $*"
  fails=$((fails + 1))
}

# ── 1. Shebangs and per-interpreter syntax checks ───────────────────────
# bootstrap.sh once had a leading space before its '#!', which means no
#   shebang at all; and every script should at least parse.
echo "· shebang + syntax checks"
while IFS= read -r f; do
  case "$f" in
    *.ps1 | *.plist | *.json | *.md | *.txt | *.yml | *.ttf) continue ;;
    vim.symlink/bundle/*) continue ;; # vendored subtree, not ours to lint
  esac
  [ -f "$f" ] || continue
  firstline=$(head -1 "$f" | tr -d '\0') # tr: binary files would warn about null bytes
  case "$firstline" in
    '#!'*) : ;;
    *) continue ;; # not a script (or shebang-less config); other checks cover those
  esac
  case "$firstline" in
    *bash*) bash -n "$f" || err "bash syntax error in $f" ;;
    *zsh*)
      if command -v zsh >/dev/null; then
        zsh -n "$f" || err "zsh syntax error in $f"
      else
        echo "  (zsh not installed; skipped $f)"
      fi
      ;;
    '#!/bin/sh'*) sh -n "$f" || err "sh syntax error in $f" ;;
  esac
done < <(git ls-files)

# every tracked .fish file must parse
if command -v fish >/dev/null; then
  while IFS= read -r f; do
    fish -n "$f" || err "fish syntax error in $f"
  done < <(git ls-files '*.fish')
else
  echo "  (fish not installed; skipped fish syntax checks)"
fi

# ── 2. Entry points must be executable with a shebang at byte zero ──────
echo "· entry-point executability"
for f in bootstrap.sh install_symlinks.sh provision-mac.sh provision-linux.sh bin.homelink/*; do
  [ -f "$f" ] || continue
  [ -x "$f" ] || err "$f is not executable"
  [ "$(head -c 2 "$f")" = "#!" ] || err "$f has no shebang at byte zero"
done

# ── 3. functions/ autoload convention ────────────────────────────────────
# Every file in fish.configlink/functions/ must define a function matching
#   its own name; a file with bare top-level statements runs them as a side
#   effect the moment the name is typed, then reports "Unknown command"
#   (see the activate-deepl.fish removal for a live instance).
echo "· fish functions wrap convention"
for f in fish.configlink/functions/*.fish; do
  name=$(basename "$f" .fish)
  grep -qE "^function[[:space:]]+$name([[:space:]]|\$)" "$f" \
    || err "$f does not define 'function $name' at top level"
done

# ── 4. Python files must at least compile ───────────────────────────────
echo "· python compile checks"
if command -v python3 >/dev/null; then
  while IFS= read -r f; do
    python3 -m py_compile "$f" || err "python compile error in $f"
  done < <(git ls-files '*.py')
else
  echo "  (python3 not installed; skipped)"
fi

# ── 5. Tracked symlink hygiene ───────────────────────────────────────────
# A tracked symlink with an absolute target can't survive a machine change
#   (the fzf key-bindings link died exactly this way when /usr/local became
#   /opt/homebrew); targets must be relative and resolve inside the repo.
echo "· tracked symlink hygiene"
while IFS= read -r f; do
  target=$(readlink "$f")
  case "$target" in
    /*) err "tracked symlink $f has an absolute target ($target)" ;;
    *)
      resolved=$(cd "$(dirname "$f")" 2>/dev/null && cd "$(dirname "$target")" 2>/dev/null && pwd -P)/$(basename "$target")
      case "$resolved" in
        "$REPO_ROOT"/*) [ -e "$resolved" ] || err "tracked symlink $f is broken ($target)" ;;
        *) err "tracked symlink $f points outside the repo ($target)" ;;
      esac
      ;;
  esac
done < <(git ls-files -s | awk '$1 == "120000" {print $4}')

# ── 6. Brewfile grammar ──────────────────────────────────────────────────
# The audit scripts parse the Brewfile line-by-line and silently skip
#   anything they don't recognize - so a typo'd directive would simply be
#   invisible to every check. Catch it here instead.
echo "· Brewfile grammar"
bad=$(grep -vE "^[[:space:]]*(#|$|tap[[:space:]]|brew[[:space:]]|cask[[:space:]]|mas[[:space:]])" install_lists/Brewfile || true)
if [ -n "$bad" ]; then
  while IFS= read -r line; do
    err "unrecognized Brewfile line: $line"
  done <<<"$bad"
fi

# ── 7. No install-suffix files below the installer's reach ──────────────
# install_symlinks.sh finds *.symlink/*.homelink/*.configlink at maxdepth 2
#   only; one nested deeper is silently never installed. (gui-editors/ is
#   excluded on purpose - its setup-all.sh handles its own linking.)
echo "· suffix-file depth"
# NB -mindepth would suppress the prune expressions at shallow depths, so
#   depth >= 3 is encoded as a path pattern instead
while IFS= read -r f; do
  err "$f is too deep for install_symlinks.sh (maxdepth 2) and will never be linked"
done < <(find . \
  \( -path ./.git -o -path ./gui-editors -o -name node_modules \) -prune -o \
  \( -name '*.symlink' -o -name '*.homelink' -o -name '*.configlink' \) -path './*/*/*' -print)

# ── 8. ShellCheck, error severity only ──────────────────────────────────
# The error tier catches "parses fine, does the wrong thing" bugs (unquoted
#   $@ re-splitting arguments, arrays flattened in [[ ]], iterating ls) with
#   near-zero noise. Deliberately NOT warning/style level: the inherited
#   scripts would drown the signal, and an ignorable check is worse than
#   none. shellcheck comes from the Brewfile; both GitHub runner images
#   ensure it in ci.yml.
echo "· shellcheck (severity=error)"
if command -v shellcheck >/dev/null; then
  sc_files=()
  while IFS= read -r f; do
    case "$f" in
      vim.symlink/bundle/*) continue ;;
    esac
    [ -f "$f" ] || continue
    if head -1 "$f" | tr -d '\0' | grep -qE '^#!.*(bash|/bin/sh)'; then
      sc_files+=("$f")
    fi
  done < <(git ls-files)
  if ! shellcheck --severity=error "${sc_files[@]}"; then
    err "shellcheck found errors (see above)"
  fi
else
  echo "  (shellcheck not installed; skipped)"
fi

if [ $fails -ne 0 ]; then
  echo "lint: $fails failure(s)"
  exit 1
fi
echo "lint: all checks passed"
