# dotfiles

Personal macOS/Linux dotfiles. A fork of [sjml/dotfiles](https://github.com/sjml/dotfiles),
tracked as a real `upstream` git remote alongside `origin` (`dickansj/dotfiles`) —
not a one-time copy. Check `git log main..upstream/main` for changes worth
pulling in; diff specific files against `$(git merge-base main upstream/main)`
before assuming a diff is content drift vs. just upstream's periodic
`fish_indent` reformatting (they use tabs, this repo uses spaces — expect noisy
whitespace-only hunks).

## Repo structure

The symlink target is encoded in the filename suffix — this is the whole
mechanism, there's no separate manifest:

| Suffix | Destination | Example |
|---|---|---|
| `*.symlink` | `~/.<name>` | `gitconfig.symlink` → `~/.gitconfig` |
| `*.configlink` | `~/.config/<name>` | `fish.configlink` → `~/.config/fish` |
| `*.homelink` | `~/<name>` | `bin.homelink` → `~/bin` |
| `osx-launchagents/*.plist` | `~/Library/LaunchAgents/<name>` | |
| `osx-dictionaries/LocalDictionary` | hardcoded (see below) | |

Note `*.configlink`/`*.homelink` link the whole directory in one shot (not
file-by-file), so e.g. `~/.config/fish` is itself a symlink to
`fish.configlink/` — editing any file under `fish.configlink/` edits the live
config immediately, no re-linking needed. New top-level `*.symlink`/
`*.homelink`/`*.configlink` entries do need `install_symlinks.sh` re-run.

`osx-dictionaries/` breaks from the filename-suffix convention: its one
tracked word list, `LocalDictionary`, has a fixed destination
(`~/Library/Spelling/LocalDictionary` — macOS's shared system spell-check
list, which BBEdit and most other Cocoa apps defer to instead of keeping
their own) that `install_symlinks.sh`'s `install_dictionaries()` hardcodes
explicitly, symlinking it like everything else. Word's custom dictionary
(`~/Library/Group Containers/UBF8T346G9.Office/Custom Dictionary`, UTF-16LE
+ CRLF) is *not* tracked here — it's generated: symlinking it once broke
Word outright (it tracks the file by more than its path, likely a
security-scoped bookmark), so `bin.homelink/syncdict` two-way-merges it
with `LocalDictionary` instead — union of both lists written back to both
sides, so words learned inside Word flow back into the repo and nothing is
ever clobbered. This now runs automatically: a `WatchPaths` LaunchAgent
(`osx-launchagents/com.jdickan.syncdict.plist`) fires the sync the moment
either file changes. It runs a *compiled* binary
(`utility/syncdict-agent.rs`, built by `install_dictionaries()` via a bare
`rustc` when available) rather than the `syncdict` script itself — macOS's
Full Disk Access protection on Word's Group Container checks the identity
of whatever process performs the file I/O, which for a shell script is
always the interpreter (`/bin/bash`) regardless of which script triggered
it, so only a real compiled binary can be granted access narrowly instead
of handing it to `/bin/bash` wholesale. `syncdict` itself is still there for
running by hand (e.g. right after "Add to Dictionary" in Word, without
waiting on the watcher). Full story, including the one-time Full Disk
Access grant a new machine needs, in `osx-dictionaries/README.md`. The
tracked list is seeded with real accumulated vocabulary rather than
starting empty, same spirit as upstream's `cspell-words.txt` for VS Code.

Supporting directories (not part of the symlink convention):
- `install_lists/` — Brewfile (primary), plus `r-packages.txt` (kept manually,
  not consumed by any script — same for anything else added here going
  forward unless something is written to actually use it) and
  `setapp-install.txt` (generated, don't hand-edit: a Hazel rule regenerates
  it via an embedded copy of `utility/setapp-install.sh` whenever a Setapp
  app is added — and since `hazel/Setapp.hazelrules` is a binary export,
  changing that script means updating the rule inside Hazel by hand too).
- `resources/` — fonts, Terminal profile, Office templates, `ssh_config.base`.
- `utility/` — helper scripts, git-subtree tooling, one-off Python utilities.
- `gui-editors/`, `hazel/` — editor extensions and Hazel rules, installed
  separately from the main provision flow.

## Bootstrap / install

Three layers, thin to thick — only the top one is meant to be run on a truly
fresh machine:

1. **`bootstrap.sh`** (`.ps1` on Windows) — the `curl | bash` entry point.
   Downloads a tarball (no git needed yet) to `~/.dotfiles`, then dispatches to
   `provision-mac.sh` or `provision-linux.sh` based on `$OSTYPE`.
2. **`install_symlinks.sh`** — OS-agnostic, idempotent, safe to re-run any
   time. Walks the repo for `*.symlink`/`*.homelink`/`*.configlink` and links
   each via `link_file()` (in `utility/utility_functions.sh`), which prompts
   interactively on conflicts (skip/overwrite/backup, with "all" variants).
3. **`provision-mac.sh`** — heavy, **non-idempotent, run-once-on-a-fresh-Mac**
   (says so explicitly at the top; don't re-run on an already-provisioned
   machine). Runs `install_symlinks.sh`, installs Homebrew + Rosetta, `brew
   bundle`s the Brewfile, sets fish as login shell, re-inits git if needed,
   symlinks itself into `~/Projects/dotfiles`, installs Vundle vim bundles,
   then a long tail of `defaults write` calls for Finder/Trackpad/Dock/Safari,
   ending with `dockutil` Dock setup.
   `provision-linux.sh` is the stripped-down sibling (no sudo assumed):
   symlinks, self-link into `~/Projects/dotfiles`, vim bundles, pyenv.

Python, Ruby, Node, and Rust are all plain Homebrew formulae now (`brew
'python'`, `brew 'ruby'`, `brew 'node'`, `brew 'rustup'`) — the old
asdf-managed-multi-version setup was fully removed from `provision-mac.sh`,
not just paused; there's no plugin list or version-pinning to revive.
Homebrew keeps some formulae keg-only when macOS ships its own version, or
to avoid clobbering a manually-managed toolchain (python, ruby, rustup, and
the `-full` variants of imagemagick/ffmpeg all hit this) — keg-only means no
automatic PATH entry, so each one needs an explicit line in `path.fish`'s
"Installed stuff" block or the shell silently falls back to Apple's
ancient bundled version (or, for rustup, just isn't reachable at all —
Homebrew ships its `cargo`/`rustc`/etc. proxy binaries directly in the keg's
own `bin/`, not in `~/.cargo/bin` the way the native rustup.rs installer
does). Found and fixed six of these this session (python, ruby, rustup,
sqlite, trash, mozjpeg) before writing `utility/check_keg_only_paths.py` to
catch the rest mechanically — see Package management below.

`pip` (the `bin.homelink/pip` wrapper) intentionally does *not* try to
install anything outside an active virtualenv — Homebrew's Python is
externally-managed (PEP 668) and refuses bare `pip install` outside a venv
regardless, so the wrapper just fails with a pointer to `uv` instead
(`uv tool install` for a CLI tool, `uv venv && uv pip install` for a
project).

Rust specifically: `brew 'rustup'` only installs the toolchain multiplexer,
not an actual toolchain (same two-step split as pyenv/asdf) — `brew info
rustup` even shows `rustup self update` disabled in favor of `brew upgrade
rustup`, a deliberate Homebrew choice, not a bug. `provision-mac.sh` runs
`rustup default stable` right after the vim bundles step to close that gap,
then immediately re-runs `install_symlinks.sh` a second time — that's not
redundant, it's what lets `install_dictionaries()`'s `rustc`-gated
`syncdict-agent` build (see osx-dictionaries above) actually happen during
the same bootstrap, since the first `install_symlinks.sh` run happens
before Homebrew (and therefore `rustc`) exists at all.
One quirk worth knowing: since path.fish's PATH ordering prefers the keg's
own `bin/` over Homebrew's `rustup` wrapper script (which redirects
`RUSTUP_OVERRIDE_UNIX_FALLBACK_SETTINGS` to `/opt/homebrew/etc/rustup/`),
rustup's actual config lives at the standard `~/.rustup/settings.toml`, not
the Homebrew-provided one — harmless, just two settings files existing where
only one is actually read.

## Package management

Homebrew via `install_lists/Brewfile` is the primary package manager —
formulae, casks, Mac App Store apps (`mas`), and taps all live there in one
file, organized into commented sections (shells/utils, languages, dev tools,
GUI apps, fonts, drivers, MAS). Add new packages to the matching section
rather than the end of the file. `utility/audit-brewfile.py` validates it
(see Working conventions below for details — it's also run as a pre-flight
gate in `provision-mac.sh` now, before any installing starts, not just via
CI); `utility/check_untracked_brew.py` checks the opposite direction —
things installed via ad-hoc `brew install` that never made it into the
Brewfile.

Two more standalone `utility/` diagnostics, same pattern as the two above:
`check_keg_only_paths.py` mechanizes the keg-only PATH check described
above. `check_orphaned_symlinks.py` is a small hand-maintained registry
checking whether a `*.symlink`'s target tool is actually installed (same
failure mode as `devbox_no_prompt`/`condarc.symlink`/`ipython.symlink`/
`virtualenv.symlink`, all removed this session). All three of these plus
`check_untracked_brew.py` are hooked into `bin.homelink/envup`'s
`all_check()`, so bare `envup` (which already defaults to `check all`)
surfaces all four automatically.

Some casks intentionally aren't Brewfile-managed: `marked-app` is commented
out and pinned locally (`brew pin marked-app`) to stay on the owned/
perpetual-license Marked 2, since the cask now tracks the subscription-based
Marked 3.

One `git subtree` is in active use: `vim.symlink/bundle/Vundle.vim` ← upstream
`VundleVim/Vundle.vim`, tracked in `utility/git_subtrees.txt` and managed by
the `utility/git_subtree_*.sh` scripts.

## Fish shell conventions

Fish (`fish.configlink/`) is the primary shell. Files under
`functions/` autoload by filename (`tma.fish` → `tma` command) — see
`fish.configlink/functions/README.md` for what every function does before
adding or changing one.

Conventions observed across existing functions:
- A one-to-two-line comment directly above the `function` line explaining
  purpose/origin (e.g. `# Run tmux attach, putting in a session name if
  provided`).
- Anything taking arguments echoes a `Usage: ...` string and `return 1` on bad
  invocation, rather than failing silently.
- **Every file in `functions/` must wrap its logic in `function <name> ...
  end` matching the filename.** A file with bare top-level statements is a
  real footgun: fish's autoloader sources the file the moment you type its
  name as a command, running any top-level code as a side effect, and *then*
  reports "Unknown command" if no matching function was ever defined — so it
  looks like nothing happened when it actually mutated your shell. (Found and
  fixed a live instance of this — see git history around
  `activate-deepl.fish`/`deactivate-deepl.fish` removal.)

`path.fish` builds `$PATH` manually (comment notes it's "ain't broke"
territory, deliberately not using `fish_user_paths`) — new entries go in
either the `addIfExists` block (existence-checked) or the "Installed stuff"
block (unconditional, mirrors what Homebrew itself provides).

## Public vs. private split

No secrets live in this repo. The split points:
- **`~/.local/config/config.fish`** — sourced by `fish.configlink/config.fish`
  if present, explicitly commented "not in source control." This is where
  machine-specific env vars/secrets belong, not in any `*.configlink` file.
- **`resources/ssh_config.base`** is *copied* (not symlinked) to `~/.ssh/config`
  during provisioning — deliberate, so host-specific/private entries added
  after that point never end up staged for commit.
- Interactively-prompted secrets (e.g. the DeepL API key in
  `run-translate.fish`) get written into a generated, `.gitignore`'d directory
  (`utility/deepl-env/`, ignored via its own `venv`-generated `.gitignore`),
  never into a tracked file.

## Working conventions

- This is a single-user config repo — direct commits to `main` are the norm,
  not PRs. No branch protection or required checks.
- `tests/run_all.sh` is the repo's regression suite; `.github/workflows/ci.yml`
  runs it on every push, on both Ubuntu and macOS. Each check pins a bug
  class that actually happened — when fixing a shell bug, add its
  reproduction here so it stays fixed. Run locally before committing
  anything touching shell code. It covers:
  - `lint.sh`: static checks over every tracked file — shebang-at-byte-zero,
    per-interpreter syntax checks, a ShellCheck pass at `--severity=error`
    only (the warning/style tiers would drown in noise from the inherited
    scripts), the `functions/` wrap convention, tracked-symlink hygiene,
    Brewfile grammar, suffix files nested too deep for `install_symlinks.sh`
    to find, and `.plist` well-formedness (`plutil -lint`, macOS only —
    skips quietly on Ubuntu since nothing else validates these and a
    malformed `osx-launchagents/*.plist` would otherwise go undetected
    until someone actually tried to `launchctl load` it).
  - `test_install_symlinks.sh`: a real `install_symlinks.sh` run into a
    throwaway `$HOME` (twice — the second run must skip cleanly, proving
    idempotence), plus a third run with `PATH` stripped to just the base
    system dirs, proving the `rustc`-gated `syncdict-agent` compile step
    skips gracefully instead of failing the whole install when Rust isn't
    available yet (the situation on a truly fresh machine).
  - `test_provision_linux.sh`: `provision-linux.sh`'s own logic beyond what
    `install_symlinks.sh` already covers — the SSH config copy, the
    `~/Projects/dotfiles` symlink (including that a second run doesn't
    error on it), and the git re-init sequence's exact command
    order/arguments. `git`/`vim`/`curl` are stubbed with logging no-ops
    rather than skipped, to actually exercise the script's real control
    flow without hitting the real network (git re-init talks to the real
    GitHub repo; the pyenv step curls and runs a real installer
    unconditionally, with no availability guard at all).
  - `test_fish.sh`: login-shell startup and prompt smoke tests in an
    isolated `$HOME` (including the narrow-terminal, long-path, and
    dash-named-directory cases that have broken the prompt before).
  - `test_syncdict.sh`: an encoding round-trip run against *both*
    dictionary-sync implementations — the `syncdict` bash script and a
    freshly-compiled `syncdict-agent` — asserting identical behavior, since
    they're independent implementations of the same merge logic and
    nothing else would catch them drifting apart.
  - Two portability bugs specifically worth remembering if writing more
    shell-based tests: `mktemp -t NAME` needs an explicit `XXXXXX` template
    (BSD mktemp tolerates a bare prefix; GNU mktemp errors on it), and
    `stat -f` means completely different things on BSD vs. GNU (a format
    string vs. "show filesystem status" — GNU's doesn't even error, it
    just silently succeeds with garbage output, so branch on `uname`
    explicitly rather than relying on one command failing).
  - Not covered, and not easily fixable: `provision-mac.sh` itself (real,
    non-idempotent system mutation — Homebrew, `defaults write`, Dock,
    Rosetta — can't safely run in CI), and the `utility/check_*.py`/
    `audit-brewfile.py` scripts (need live Homebrew state; installing the
    whole ~270-package Brewfile just to test hygiene scripts isn't worth
    it for a single-user repo).
- `.github/workflows/check-brewfile.yml` runs `utility/audit-brewfile.py` on
  push and weekly via cron, checking every `brew`/`cask`/`mas` entry in the
  Brewfile against the live Homebrew/App Store catalogs. Originally inherited
  from upstream sjml and silently red for years (GitHub had auto-disabled its
  schedule from inactivity) — fixed and re-enabled in this session. The
  script now accounts for Homebrew's formula aliases and cask `old_tokens`
  when checking names, so a real failure means something's actually gone
  (confirm with `python3 utility/audit-brewfile.py` locally, which caches
  `utility/formula.json`/`cask.json` for a week — delete them to force a
  fresh fetch sooner). `check_untracked_brew.py` shares the same cache
  files and expiry, and keeps a `KNOWN_UNMANAGED` allowlist for apps
  that are installed on purpose but deliberately not Brewfile-managed
  (the pinned Affinity V2 trio, Marked 2, etc.) so routine `envup` runs
  stay quiet.
- Commit messages: explain *why*, not just what changed; keep them to a few
  lines, no verbose bullet essays.
- When pulling a change in from `upstream/main`, check whether it's entangled
  with an unrelated reformatting/grab-bag commit before cherry-picking —
  hand-apply the substantive lines instead if so, rather than dragging in
  unrelated file changes.
- Before adding a fish function or config change, test it in a fresh `fish -c
  '...'` subshell (not just visual inspection) — the autoload footgun above is
  exactly the kind of bug that only shows up at invocation time.
