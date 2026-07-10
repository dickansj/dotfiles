# osx-dictionaries

Spell-check vocabulary for macOS, tracked here so a fresh machine inherits
accumulated words instead of starting blank — same idea as upstream sjml's
`cspell-words.txt` for VS Code, just for the apps actually used day to day
here (Word, BBEdit).

## `LocalDictionary`
The one file you actually hand-edit. Plain UTF-8, one word per line.
Symlinked to `~/Library/Spelling/LocalDictionary` — macOS's shared system
spell-check word list. BBEdit doesn't keep its own dictionary; like most
Cocoa apps (Mail, TextEdit, Notes, Safari, ...) it defers to this one via
`NSSpellChecker`. This is set up by `install_dictionaries()` in
[`install_symlinks.sh`](../install_symlinks.sh), which — along with the rest
of that script's suffix-based conventions — breaks from them here since this
file's destination is a fixed, hardcoded path rather than a name-derived one.

## Word's custom dictionary
Not tracked in this repo at all — it's a generated file, derived entirely
from `LocalDictionary` by [`bin.homelink/syncdict`](../bin.homelink/syncdict)
(`~/bin/syncdict` once installed), which runs automatically as part of
`install_dictionaries()` on every install/re-run. Its live location is
`~/Library/Group Containers/UBF8T346G9.Office/Custom Dictionary`, in Word's
native UTF-16LE-with-CRLF format — kept in that format on write, never
converted to plain text on disk.

It can't be symlinked to `LocalDictionary` the way the system dictionary is:
symlinking it once broke Word outright ("Remove" greyed out, "Edit..." did
nothing in Word's own Dictionaries panel, and previously-learned words
started getting flagged as misspelled). Word tracks a custom dictionary by
more than its path — likely a security-scoped bookmark captured against the
file's identity at the time it was added — and swapping in a symlink
invalidated that reference. A generated copy avoids the problem.

`syncdict` is a two-way merge, not a one-way overwrite: it reads whatever's
currently in Word's live dictionary (in case you've used "Add to Dictionary"
inside Word since the last sync), unions it with `LocalDictionary`, sorts the
result case-insensitively, and writes the merged list back to *both* — so
running it is always safe and never loses words learned on either side.
Case variants (`Pneumatological` vs. `pneumatological`) are deduped on exact
match only, so both are kept as distinct entries.

Run it manually any time after adding words directly in Word:
```shell-script
syncdict
```

Encoding-wise, the merge pipeline (`iconv` for UTF-16LE↔UTF-8, plain
byte-safe `sed`/`sort`/`awk` for the rest) has been verified round-trip-safe
for Greek, Arabic, and Syriac, including precomposed combining characters
(e.g. `Bardaiṣan`'s dot-below) — nothing gets silently mangled or dropped
converting between formats.
