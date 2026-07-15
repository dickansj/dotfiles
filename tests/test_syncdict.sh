#!/usr/bin/env bash

# Round-trips syncdict's encoding pipeline in an isolated $HOME: seeds a
#   canonical UTF-8/LF list and a Word-style UTF-16LE+BOM+CRLF dictionary
#   with partially-overlapping words (including non-Latin scripts and
#   combining characters), then checks the merge is a true union written
#   correctly to both sides, that no BOM leaks into the canonical list,
#   and that a second run changes nothing.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
FAKE_HOME="$(mktemp -d)"
trap 'rm -rf "$FAKE_HOME"' EXIT

fails=0
err() {
  echo "  ❌ $*"
  fails=$((fails + 1))
}

# syncdict hardcodes $HOME/.dotfiles, so build just enough of it
mkdir -p "$FAKE_HOME/.dotfiles/osx-dictionaries" "$FAKE_HOME/.dotfiles/bin.homelink"
cp "$REPO_ROOT/bin.homelink/syncdict" "$FAKE_HOME/.dotfiles/bin.homelink/"
canonical="$FAKE_HOME/.dotfiles/osx-dictionaries/LocalDictionary"
worddict="$FAKE_HOME/Library/Group Containers/UBF8T346G9.Office/Custom Dictionary"

printf 'zebra\napple\nBardaiṣan\n' >"$canonical"

mkdir -p "$(dirname "$worddict")"
{
  printf '\xff\xfe'
  printf 'apple\r\nmango\r\nΣυρία\r\n' | iconv -f UTF-8 -t UTF-16LE
} >"$worddict"

echo "· first sync"
if ! HOME="$FAKE_HOME" "$FAKE_HOME/.dotfiles/bin.homelink/syncdict" >"$FAKE_HOME/sync1.log" 2>&1; then
  err "syncdict exited nonzero"
  cat "$FAKE_HOME/sync1.log"
fi

expected_words=$(printf 'apple\nBardaiṣan\nmango\nzebra\nΣυρία\n' | sort)

# canonical side: UTF-8/LF union, no BOM, no CRs
if [ "$(sort "$canonical")" != "$expected_words" ]; then
  err "canonical list is not the expected union:"
  sed 's/^/      /' "$canonical"
fi
if grep -q $'\xef\xbb\xbf' "$canonical"; then
  err "a BOM leaked into the canonical list"
fi
if grep -q $'\r' "$canonical"; then
  err "carriage returns leaked into the canonical list"
fi

# Word side: BOM intact, CRLF line endings, same union after decoding
if [ "$(head -c 2 "$worddict" | od -An -tx1 | tr -d ' ')" != "fffe" ]; then
  err "Word dictionary lost its UTF-16LE BOM"
fi
decoded=$(iconv -f UTF-16LE -t UTF-8 "$worddict" | sed '1s/^\xEF\xBB\xBF//')
if [ "$(printf '%s' "$decoded" | tr -d '\r' | sort)" != "$expected_words" ]; then
  err "Word dictionary is not the expected union after decoding"
fi
if printf '%s' "$decoded" | grep -qv $'\r$'; then
  err "Word dictionary has lines without CRLF endings"
fi

echo "· second sync (idempotence)"
sum_before=$(cksum "$canonical"; cksum "$worddict")
if ! HOME="$FAKE_HOME" "$FAKE_HOME/.dotfiles/bin.homelink/syncdict" >"$FAKE_HOME/sync2.log" 2>&1; then
  err "syncdict exited nonzero on re-run"
  cat "$FAKE_HOME/sync2.log"
fi
sum_after=$(cksum "$canonical"; cksum "$worddict")
if [ "$sum_before" != "$sum_after" ]; then
  err "re-running syncdict changed the files (not idempotent)"
fi

if [ $fails -ne 0 ]; then
  echo "test_syncdict: $fails failure(s)"
  exit 1
fi
echo "test_syncdict: all checks passed"
