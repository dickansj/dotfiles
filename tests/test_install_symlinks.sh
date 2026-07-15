#!/usr/bin/env bash

# Exercises install_symlinks.sh for real: copies the repo into a throwaway
#   $HOME (mirroring the layout bootstrap.sh creates), runs the installer
#   non-interactively, and checks every suffix convention produced the link
#   it promises. Then runs it a second time to prove idempotence - a re-run
#   must skip cleanly, never prompt, never relink.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
# resolve the temp dir physically up front: on macOS mktemp hands back a
#   path under /var, which is a symlink to /private/var - install_symlinks
#   records targets via pwd -P, so comparisons must use the same form
FAKE_HOME="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$FAKE_HOME"' EXIT

fails=0
err() {
  echo "  ❌ $*"
  fails=$((fails + 1))
}

# lay the repo out the way bootstrap.sh does (~/.dotfiles), minus git
#   metadata and the big gitignored caches
mkdir -p "$FAKE_HOME/.dotfiles"
tar -C "$REPO_ROOT" \
  --exclude '.git' \
  --exclude 'utility/deepl-env' \
  --exclude 'utility/formula.json' \
  --exclude 'utility/cask.json' \
  -cf - . | tar -xf - -C "$FAKE_HOME/.dotfiles"
DOTS="$FAKE_HOME/.dotfiles"

run_install() {
  HOME="$FAKE_HOME" "$DOTS/install_symlinks.sh" </dev/null >"$1" 2>&1
}

check_link() { # $1 = expected link, $2 = expected target
  if [ ! -L "$1" ]; then
    err "expected symlink missing: $1"
  elif [ "$(readlink "$1")" != "$2" ]; then
    err "$1 points at '$(readlink "$1")', expected '$2'"
  fi
}

check_all_links() {
  local f base
  for f in "$DOTS"/*.symlink; do
    base=$(basename "$f")
    check_link "$FAKE_HOME/.${base%.symlink}" "$f"
  done
  for f in "$DOTS"/*.homelink; do
    base=$(basename "$f")
    check_link "$FAKE_HOME/${base%.homelink}" "$f"
  done
  for f in "$DOTS"/*.configlink; do
    base=$(basename "$f")
    check_link "$FAKE_HOME/.config/${base%.configlink}" "$f"
  done
  if [ "$(uname)" = "Darwin" ]; then
    for f in "$DOTS"/osx-launchagents/*.plist; do
      check_link "$FAKE_HOME/Library/LaunchAgents/$(basename "$f")" "$f"
    done
    check_link "$FAKE_HOME/Library/Spelling/LocalDictionary" "$DOTS/osx-dictionaries/LocalDictionary"
    worddict="$FAKE_HOME/Library/Group Containers/UBF8T346G9.Office/Custom Dictionary"
    if [ ! -s "$worddict" ]; then
      err "syncdict did not generate Word's custom dictionary"
    elif [ "$(head -c 2 "$worddict" | od -An -tx1 | tr -d ' ')" != "fffe" ]; then
      err "Word dictionary is missing its UTF-16LE BOM"
    fi
  fi
}

echo "· first run into empty \$HOME"
if ! run_install "$FAKE_HOME/run1.log"; then
  err "install_symlinks.sh exited nonzero on first run"
  cat "$FAKE_HOME/run1.log"
fi
if grep -q "File already exists" "$FAKE_HOME/run1.log"; then
  err "first run into an empty \$HOME hit a conflict prompt"
fi
check_all_links

echo "· second run (idempotence)"
if ! run_install "$FAKE_HOME/run2.log"; then
  err "install_symlinks.sh exited nonzero on re-run"
  cat "$FAKE_HOME/run2.log"
fi
if grep -q "File already exists" "$FAKE_HOME/run2.log"; then
  err "re-run prompted about conflicts instead of skipping its own links"
fi
if grep -q "^linked" "$FAKE_HOME/run2.log"; then
  err "re-run re-linked files instead of skipping them"
fi
check_all_links

if [ $fails -ne 0 ]; then
  echo "test_install_symlinks: $fails failure(s)"
  exit 1
fi
echo "test_install_symlinks: all checks passed"
