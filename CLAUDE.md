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

Note `*.configlink`/`*.homelink` link the whole directory in one shot (not
file-by-file), so e.g. `~/.config/fish` is itself a symlink to
`fish.configlink/` — editing any file under `fish.configlink/` edits the live
config immediately, no re-linking needed. New top-level `*.symlink`/
`*.homelink`/`*.configlink` entries do need `install_symlinks.sh` re-run.

Supporting directories (not part of the symlink convention):
- `install_lists/` — Brewfile, conda envs, Python/Node/R package lists.
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

Most of the asdf/language-runtime block (Python/Ruby/Node/Rust versions) in
`provision-mac.sh` is currently commented out — treat that as intentionally
disabled, not accidental, unless told otherwise.

## Package management

Homebrew via `install_lists/Brewfile` is the primary package manager —
formulae, casks, Mac App Store apps (`mas`), and taps all live there in one
file, organized into commented sections (shells/utils, languages, dev tools,
GUI apps, fonts, drivers, MAS). Add new packages to the matching section
rather than the end of the file. `install_lists/` also holds conda envs
(`conda-nlp.yml`, `conda-scimath.yml`) and Python/Node/R package lists for
what's left of the asdf-based setup.

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
- `.github/workflows/check-brewfile.yml` runs `utility/audit-brewfile.py` on
  push and weekly via cron, checking every `brew`/`cask`/`mas` entry in the
  Brewfile against the live Homebrew/App Store catalogs. Originally inherited
  from upstream sjml and silently red for years (GitHub had auto-disabled its
  schedule from inactivity) — fixed and re-enabled in this session. The
  script now accounts for Homebrew's formula aliases and cask `old_tokens`
  when checking names, so a real failure means something's actually gone
  (confirm with `python3 utility/audit-brewfile.py` locally, which caches
  `utility/formula.json`/`cask.json` — delete those first to force a fresh
  fetch).
- Commit messages: explain *why*, not just what changed; keep them to a few
  lines, no verbose bullet essays.
- When pulling a change in from `upstream/main`, check whether it's entangled
  with an unrelated reformatting/grab-bag commit before cherry-picking —
  hand-apply the substantive lines instead if so, rather than dragging in
  unrelated file changes.
- Before adding a fish function or config change, test it in a fresh `fish -c
  '...'` subshell (not just visual inspection) — the autoload footgun above is
  exactly the kind of bug that only shows up at invocation time.
