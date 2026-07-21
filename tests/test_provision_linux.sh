#!/usr/bin/env bash

# Exercises provision-linux.sh's own logic (everything install_symlinks.sh
#   tests don't already cover): SSH config gets copied, ~/Projects/dotfiles
#   gets symlinked (and a re-run doesn't error on it - the guard added for
#   exactly that), and the git re-init sequence runs in the right order
#   with the right arguments.
#
# git/vim/curl are stubbed (logging what they were called with, then
#   exiting 0) rather than skipped - this is what actually exercises the
#   script's own control flow instead of just its "tool not installed"
#   fallback branches, without hitting the real network (git re-init talks
#   to a real GitHub repo; the pyenv step curls and runs a real installer
#   unconditionally, with no availability guard at all). The "tool not
#   installed" branches themselves aren't tested here - simulating that
#   reliably across platforms is its own headache (macOS ships its own
#   git/vim in /usr/bin, so PATH-stripping doesn't actually remove them
#   the way it does rustc, which only exists via Homebrew), and the
#   branches themselves are simple enough (a bare length check + echo)
#   not to need it.
#
# provision-linux.sh's first line, `exec </dev/tty >/dev/tty`, fails in
#   any headless/CI environment (no controlling terminal) - documented
#   bash behavior for a bare exec's redirection failure is to return 1,
#   not kill the shell, and the script has no `set -e`, so this is already
#   safe; just noisy. Expected, not asserted against here.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

fails=0
err() {
  echo "  ❌ $*"
  fails=$((fails + 1))
}

CLEANUP_PATHS=()
cleanup() {
  local p
  for p in "${CLEANUP_PATHS[@]:-}"; do
    [ -n "$p" ] && rm -rf "$p"
  done
}
trap cleanup EXIT

# a stub bin/ dir shadowing git, vim, and curl ahead of the real PATH -
#   each logs its own arguments to its own file and exits 0
make_stub_bin() {
  local dir="$1" log_dir="$2"
  mkdir -p "$dir"
  local cmd
  for cmd in git vim curl; do
    cat >"$dir/$cmd" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$log_dir/$cmd.log"
exit 0
EOF
    chmod +x "$dir/$cmd"
  done
}

setup_fake_home() {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"
  mkdir -p "$fake_home/.dotfiles"
  tar -C "$REPO_ROOT" \
    --exclude '.git' \
    --exclude 'utility/deepl-env' \
    --exclude 'utility/formula.json' \
    --exclude 'utility/cask.json' \
    -cf - . | tar -xf - -C "$fake_home/.dotfiles"
  echo "$fake_home"
}

echo "· first run: SSH config, Projects symlink, git re-init sequence"
FAKE_HOME="$(setup_fake_home)"
CLEANUP_PATHS+=("$FAKE_HOME")
STUB_BIN="$FAKE_HOME/stub-bin"
make_stub_bin "$STUB_BIN" "$FAKE_HOME"

if ! HOME="$FAKE_HOME" PATH="$STUB_BIN:$PATH" \
  "$FAKE_HOME/.dotfiles/provision-linux.sh" </dev/null >"$FAKE_HOME/run1.log" 2>&1; then
  err "provision-linux.sh exited nonzero"
  cat "$FAKE_HOME/run1.log"
fi

if [ ! -f "$FAKE_HOME/.ssh/config" ]; then
  err "SSH config was not copied"
elif ! diff -q "$REPO_ROOT/resources/ssh_config.base" "$FAKE_HOME/.ssh/config" >/dev/null; then
  err "SSH config content doesn't match resources/ssh_config.base"
fi
if [ -d "$FAKE_HOME/.ssh" ]; then
  perms=$(stat -f '%Lp' "$FAKE_HOME/.ssh" 2>/dev/null || stat -c '%a' "$FAKE_HOME/.ssh" 2>/dev/null)
  [ "$perms" = "700" ] || err "~/.ssh is mode $perms, expected 700"
fi

if [ ! -L "$FAKE_HOME/Projects/dotfiles" ]; then
  err "~/Projects/dotfiles was not symlinked"
elif [ "$(readlink "$FAKE_HOME/Projects/dotfiles")" != "$FAKE_HOME/.dotfiles" ]; then
  err "~/Projects/dotfiles points at $(readlink "$FAKE_HOME/Projects/dotfiles"), expected $FAKE_HOME/.dotfiles"
fi

# git ran (found via the stub on PATH), so the reinit branch should have
#   fired - init, checkout -b main, remote add origin, fetch, reset,
#   set-upstream-to, checkout ., then later remote set-url to ssh
git_log="$FAKE_HOME/git.log"
if [ ! -f "$git_log" ]; then
  err "git was never called"
else
  expected='init
checkout -b main
remote add origin https://github.com/dickansj/dotfiles.git
fetch
reset origin/main
branch --set-upstream-to=origin/main main
checkout .
remote set-url origin git@github.com:dickansj/dotfiles.git'
  actual=$(cat "$git_log")
  if [ "$actual" != "$expected" ]; then
    err "git was called in an unexpected sequence:"
    echo "      --- expected ---"
    echo "$expected" | sed 's/^/      /'
    echo "      --- actual ---"
    echo "$actual" | sed 's/^/      /'
  fi
fi

echo "· second run: re-running doesn't error on an existing Projects symlink"
if ! HOME="$FAKE_HOME" PATH="$STUB_BIN:$PATH" \
  "$FAKE_HOME/.dotfiles/provision-linux.sh" </dev/null >"$FAKE_HOME/run2.log" 2>&1; then
  err "provision-linux.sh exited nonzero on re-run"
  cat "$FAKE_HOME/run2.log"
fi
if [ ! -L "$FAKE_HOME/Projects/dotfiles" ]; then
  err "~/Projects/dotfiles is gone after the second run"
fi

if [ $fails -ne 0 ]; then
  echo "test_provision_linux: $fails failure(s)"
  exit 1
fi
echo "test_provision_linux: all checks passed"
