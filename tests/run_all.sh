#!/usr/bin/env bash

# Runs every test in this directory; exits nonzero if any fail.
# Same entry point locally and in CI (.github/workflows/ci.yml).

set -u
cd "$(dirname "$0")"

fails=0
for t in lint.sh test_*.sh; do
  echo "════ $t"
  if bash "$t"; then
    echo "──── PASS: $t"
  else
    echo "──── FAIL: $t"
    fails=$((fails + 1))
  fi
  echo
done

if [ $fails -ne 0 ]; then
  echo "❌  $fails test script(s) failed."
  exit 1
fi
echo "🎉  All test scripts passed."
