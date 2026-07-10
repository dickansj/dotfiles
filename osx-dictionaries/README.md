# osx-dictionaries

Spell-check custom dictionaries for macOS, tracked here so a fresh machine
inherits accumulated vocabulary instead of starting blank. Handled by
`install_dictionaries()` in [`install_symlinks.sh`](../install_symlinks.sh),
which runs automatically on macOS as part of both `provision-mac.sh` (fresh
bootstrap) and any manual re-run of `install_symlinks.sh` — no separate setup
step needed.

This directory breaks from the repo's usual filename-suffix convention
(`*.symlink`/`*.homelink`/`*.configlink`) since the two files here have
fixed, unrelated destinations rather than a shared parent directory, so
`install_dictionaries()` hardcodes each src/dst pair explicitly. The two are
also handled differently from each other:

## `LocalDictionary`
→ `~/Library/Spelling/LocalDictionary` — **symlinked**.

macOS's shared system spell-check word list. BBEdit doesn't keep its own
dictionary; like most Cocoa apps (Mail, TextEdit, Notes, Safari, ...) it
defers to this one via `NSSpellChecker`. Plain UTF-8, one word per line.
Currently empty — nothing's been learned into it yet on this machine.

## `Word Custom Dictionary`
→ `~/Library/Group Containers/UBF8T346G9.Office/Custom Dictionary` —
**copied once, not symlinked**.

Word keeps its own separate custom dictionary, not shared with the system
one above. UTF-16LE with CRLF line endings — that's Word's native format for
this file, left as-is rather than converted.

This one is copied rather than symlinked because symlinking it broke Word
outright: "Remove" was greyed out and "Edit..." silently did nothing in
Word's own Dictionaries panel, and previously-learned words (`Dickan`,
`Homoiousian`, ...) started getting flagged as misspelled. Word appears to
track a custom dictionary by more than its path — likely a security-scoped
bookmark captured against the file's identity at the time it was added —
and swapping in a symlink invalidated that reference. A plain copy avoids
the problem entirely.

The copy only happens if nothing already exists at the destination, so
re-running `install_symlinks.sh` later never clobbers words Word has
learned since. The tradeoff: unlike `LocalDictionary`, new words Word learns
afterward do **not** flow back into this repo automatically. To pull in
new vocabulary, manually re-copy:
```shell-script
cp ~/Library/Group\ Containers/UBF8T346G9.Office/Custom\ Dictionary "osx-dictionaries/Word Custom Dictionary"
```
and commit the result.

Both files were seeded from real accumulated vocabulary rather than started
empty — same idea as upstream sjml's `cspell-words.txt` for VS Code, just
for the apps actually used day to day here (Word, BBEdit) instead.
