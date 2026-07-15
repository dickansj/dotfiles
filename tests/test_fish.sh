#!/usr/bin/env bash

# Fish config smoke tests in an isolated $HOME: a login shell must start
#   with zero stderr on a machine missing optional tools (thefuck, direnv,
#   brew...), every functions/ file must autoload, and the prompt must
#   render without errors in the exact situations that have broken it
#   before: narrow terminals, over-long paths, and directories whose names
#   start with a dash.

set -u
command -v fish >/dev/null || { echo "fish not installed; skipping"; exit 0; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
FAKE_HOME="$(mktemp -d)"
trap 'rm -rf "$FAKE_HOME"' EXIT

fails=0
err() {
  echo "  ❌ $*"
  fails=$((fails + 1))
}

# a fresh-machine copy of the config: no fish_variables, no ~/bin
mkdir -p "$FAKE_HOME/.config"
cp -R "$REPO_ROOT/fish.configlink" "$FAKE_HOME/.config/fish"
rm -f "$FAKE_HOME/.config/fish/fish_variables"

run_fish() { # $1 = label, rest = fish args; asserts exit 0 + clean stderr
  local label=$1
  shift
  local out="$FAKE_HOME/out.$$" errf="$FAKE_HOME/err.$$"
  if ! env -u XDG_CONFIG_HOME HOME="$FAKE_HOME" TERM=xterm-256color \
    fish "$@" >"$out" 2>"$errf"; then
    err "$label: fish exited nonzero"
    cat "$errf"
    return
  fi
  # locale warnings from minimal CI images are environmental, not ours
  if grep -v -i 'locale' "$errf" | grep -q .; then
    err "$label: stderr was not clean:"
    grep -v -i 'locale' "$errf" | sed 's/^/      /'
  fi
}

echo "· login shell startup"
run_fish "startup" -l -c 'echo __ok__'

echo "· every functions/ file autoloads under its own name"
for f in "$REPO_ROOT"/fish.configlink/functions/*.fish; do
  name=$(basename "$f" .fish)
  run_fish "autoload $name" -c "type -q $name; or begin; echo \"$name did not autoload\" 1>&2; exit 1; end"
done

echo "· prompt renders: normal width"
run_fish "prompt normal" -c 'set COLUMNS 100; set CMD_DURATION 0; fish_prompt; fish_right_prompt'

echo "· prompt renders: narrow terminal, deep path, dash-named dir"
deep="$FAKE_HOME/averyveryverylongdirectoryname/with/several/-dash-leading/nested/levels/deeper"
mkdir -p "$deep"
run_fish "prompt narrow" -c "cd $deep; set COLUMNS 20; set CMD_DURATION 0; fish_prompt"

echo "· prompt renders: alert row after a failed command"
run_fish "prompt alert" -c 'set COLUMNS 30; set CMD_DURATION 0; false; fish_prompt'

if [ $fails -ne 0 ]; then
  echo "test_fish: $fails failure(s)"
  exit 1
fi
echo "test_fish: all checks passed"
