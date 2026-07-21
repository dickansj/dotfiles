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

Runs automatically via a LaunchAgent
([`osx-launchagents/com.jdickan.syncdict.plist`](../osx-launchagents/com.jdickan.syncdict.plist))
watching both files with `WatchPaths` — edit either one and the other picks
it up within moments, no manual step needed. Can still be run by hand any
time (e.g. right after adding a word in Word, if you don't want to wait for
the watcher):
```shell-script
syncdict
```

### Why the LaunchAgent runs a different binary than the `syncdict` command

The LaunchAgent doesn't actually run `syncdict` - it runs a separate
compiled binary, [`utility/syncdict-agent.rs`](../utility/syncdict-agent.rs),
built to `bin.homelink/syncdict-agent` (gitignored - it's a build artifact,
not tracked). This exists only because of a macOS permissions wrinkle:
Word's Group Container is behind Full Disk Access protection. Running
`syncdict` by hand from a terminal works fine because Terminal already has
its own Full Disk Access grant, but a LaunchAgent-spawned process has none
of its own - and critically, **that grant can't be scoped to a shell
script**. macOS checks the identity of whatever process is actually
performing the file I/O, which for an interpreted script is always the
interpreter (`/bin/bash` under launchd's minimal environment, regardless of
which script triggered it) - so granting Full Disk Access to the script's
own path does nothing; it would have to go to `/bin/bash` itself, a much
broader grant than just this one task. A compiled binary doesn't have that
problem: it's its own process identity, so Full Disk Access can be granted
to just this one executable. Hence `syncdict-agent.rs` duplicates
`syncdict`'s merge logic natively (`iconv`'s job replaced by
`char::decode_utf16`/`str::encode_utf16`) instead of calling it - it has to
own the actual file I/O itself to be the thing macOS is checking permissions
against.

`install_symlinks.sh`'s `install_dictionaries()` compiles it with a plain
`rustc -O` (no Cargo project - it's dependency-free, std library only) if
`rustc` is available, skipping quietly otherwise since this script runs
before Homebrew exists on a truly fresh machine; `provision-mac.sh` re-runs
`install_symlinks.sh` right after setting up the Rust toolchain to pick it
up then. One-time manual step on a new machine: grant Full Disk Access to
`~/.dotfiles/bin.homelink/syncdict-agent` in System Settings → Privacy &
Security → Full Disk Access, or the LaunchAgent will fail silently (check
`/tmp/syncdict.err` if words stop syncing).

Plain `rustc` output is ad-hoc signed with no fixed identifier, so its
identity isn't stable across rebuilds - macOS's TCC treated every rebuild as
a brand-new, never-seen-before binary and kept re-prompting ("syncdict-agent
would like to access data from other apps") instead of remembering a prior
grant. Fixed by explicitly re-signing after compiling
(`codesign --force --sign - --identifier com.jdickan.syncdict-agent`) so the
identity stays the same across every future rebuild - the grant should only
ever need to happen once now.

Being a union merge, it only ever *adds* words, never removes them - deleting
a word from just one file doesn't stick, since the next sync (automatic or
manual) re-adds it from whichever side still has it. To actually remove a
word, delete it from both `LocalDictionary` and Word's live dictionary before
the next sync runs.

`syncdict` only writes a file when its content would actually change, which
matters beyond avoiding needless mtime churn - it's what keeps the
LaunchAgent from retriggering itself in an infinite loop, since it watches
the very two files it writes to.

Encoding-wise, the merge pipeline (`iconv` for UTF-16LE↔UTF-8, plain
byte-safe `sed`/`sort`/`awk` for the rest) has been verified round-trip-safe
for Greek, Arabic, and Syriac, including precomposed combining characters
(e.g. `Bardaiṣan`'s dot-below) — nothing gets silently mangled or dropped
converting between formats.
