#!/usr/bin/env bash

# Round-trips the dictionary-sync encoding pipeline in an isolated $HOME:
#   seeds a canonical UTF-8/LF list and a Word-style UTF-16LE+BOM+CRLF
#   dictionary with partially-overlapping words (including non-Latin
#   scripts and combining characters), then checks the merge is a true
#   union written correctly to both sides, that no BOM leaks into the
#   canonical list, and that a second run changes nothing.
#
# Runs this against *both* implementations - bin.homelink/syncdict (bash,
#   for interactive use) and utility/syncdict-agent.rs (compiled, what the
#   LaunchAgent actually runs - see osx-dictionaries/README.md for why
#   there are two). They're independent implementations of the same merge
#   logic, so nothing else catches them drifting apart.

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

expected_words=$(printf 'apple\nBardaiṣan\nmango\nzebra\nΣυρία\n' | sort)

# $1 = label, $2 = path to the sync binary/script to test
check_impl() {
  local label="$1" bin="$2"
  local fake_home canonical worddict

  fake_home="$(mktemp -d)"
  CLEANUP_PATHS+=("$fake_home")

  # both implementations hardcode $HOME/.dotfiles, so build just enough of it
  mkdir -p "$fake_home/.dotfiles/osx-dictionaries"
  canonical="$fake_home/.dotfiles/osx-dictionaries/LocalDictionary"
  worddict="$fake_home/Library/Group Containers/UBF8T346G9.Office/Custom Dictionary"

  printf 'zebra\napple\nBardaiṣan\n' >"$canonical"

  mkdir -p "$(dirname "$worddict")"
  {
    printf '\xff\xfe'
    printf 'apple\r\nmango\r\nΣυρία\r\n' | iconv -f UTF-8 -t UTF-16LE
  } >"$worddict"

  echo "· $label: first sync"
  if ! HOME="$fake_home" "$bin" >"$fake_home/sync1.log" 2>&1; then
    err "$label: exited nonzero"
    cat "$fake_home/sync1.log"
  fi

  # canonical side: UTF-8/LF union, no BOM, no CRs
  if [ "$(sort "$canonical")" != "$expected_words" ]; then
    err "$label: canonical list is not the expected union:"
    sed 's/^/      /' "$canonical"
  fi
  if grep -q $'\xef\xbb\xbf' "$canonical"; then
    err "$label: a BOM leaked into the canonical list"
  fi
  if grep -q $'\r' "$canonical"; then
    err "$label: carriage returns leaked into the canonical list"
  fi

  # Word side: BOM intact, CRLF line endings, same union after decoding
  if [ "$(head -c 2 "$worddict" | od -An -tx1 | tr -d ' ')" != "fffe" ]; then
    err "$label: Word dictionary lost its UTF-16LE BOM"
  fi
  local decoded
  decoded=$(iconv -f UTF-16LE -t UTF-8 "$worddict" | sed '1s/^\xEF\xBB\xBF//')
  if [ "$(printf '%s' "$decoded" | tr -d '\r' | sort)" != "$expected_words" ]; then
    err "$label: Word dictionary is not the expected union after decoding"
  fi
  if printf '%s' "$decoded" | grep -qv $'\r$'; then
    err "$label: Word dictionary has lines without CRLF endings"
  fi

  echo "· $label: second sync (idempotence)"
  local sum_before sum_after
  sum_before=$(cksum "$canonical"; cksum "$worddict")
  if ! HOME="$fake_home" "$bin" >"$fake_home/sync2.log" 2>&1; then
    err "$label: exited nonzero on re-run"
    cat "$fake_home/sync2.log"
  fi
  sum_after=$(cksum "$canonical"; cksum "$worddict")
  if [ "$sum_before" != "$sum_after" ]; then
    err "$label: re-running changed the files (not idempotent)"
  fi
}

check_impl "syncdict (bash)" "$REPO_ROOT/bin.homelink/syncdict"

# `command -v rustc` isn't enough: rustup provides a `rustc` shim on PATH
#   even with no default toolchain configured, which fails at runtime -
#   seen for real on GitHub's macos-latest CI runner. `rustc --version`
#   actually exercises it (see install_symlinks.sh for the same fix).
if rustc --version >/dev/null 2>&1; then
  # `-t NAME` without explicit X's works on BSD/macOS mktemp but fails on
  #   GNU/Linux mktemp ("too few X's in template") - seen for real on
  #   GitHub's ubuntu-latest CI runner. Explicit XXXXXX is portable to both.
  agent_bin="$(mktemp -t 'syncdict-agent.XXXXXX')"
  CLEANUP_PATHS+=("$agent_bin")
  if compile_log=$(rustc -O -o "$agent_bin" "$REPO_ROOT/utility/syncdict-agent.rs" 2>&1); then
    check_impl "syncdict-agent (rust)" "$agent_bin"
  else
    err "syncdict-agent.rs failed to compile:"
    echo "$compile_log" | sed 's/^/      /'
  fi
else
  echo "  (rustc not installed; skipped syncdict-agent test)"
fi

if [ $fails -ne 0 ]; then
  echo "test_syncdict: $fails failure(s)"
  exit 1
fi
echo "test_syncdict: all checks passed"
