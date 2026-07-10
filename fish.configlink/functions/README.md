# fish functions

Fish autoloads any file here as a function named after the file (e.g. `tma.fish` →
`tma`), so everything below is available in any interactive shell without further
setup. A couple of files are exceptions — noted inline.

## `take`
```
take <dir>
```
Basic port of oh-my-zsh's `take`: `mkdir -p` the given directory and `cd` into it.
Handles nested paths in one shot (`take a/b/c`). Does not include OMZ's extended
behavior for URLs (download+extract) or `user/repo` (git clone) — just the plain
directory case.

## `transcribe`
```
transcribe [-l <locale>] <file1> [file2 ...]
```
Batch-transcribes audio/video files to `.srt` subtitles using
[`yap`](https://github.com/finnvoor/yap) (Apple's on-device Speech framework, runs
offline). For each file, strips the extension and writes `<name>.srt` alongside it.

- `-l`/`--locale` sets a BCP-47 locale (e.g. `en-US`, `es-ES`) and must be given
  *before* the file list — argument parsing stops at the first non-flag token.
- Skips (with a message) any argument that isn't an existing file.
- Requires `yap` (`brew 'yap'` in the [Brewfile](../../install_lists/Brewfile)).

```fish
transcribe lecture.mp4
transcribe interview1.mov interview2.mov
transcribe -l fr-FR clip.m4a
```

## `tma`
```
tma [session-name]
```
`tmux attach-session`, optionally targeting a named session. With no argument,
attaches to whatever tmux considers current.

## `tms`
```
tms [session-name]
```
`tmux new-session`, optionally with a name (`-s`). With no argument, starts an
unnamed session.

## `rtab`
```
rtab
```
Prints the current working directory shortened path-segment-by-segment down to
the minimum number of characters needed to stay unambiguous within its parent
directory — the last segment is always shown in full, and `$HOME` collapses to
`~`. Used by [`fish_prompt.fish`](fish_prompt.fish) to keep the prompt narrow.
Example: `/Users/shane/Documents/papers/final` → `~/Doc/p/final`. Not meant to be
called directly, but harmless to run standalone.

## `fish_prompt`
Not user-invoked — fish calls this automatically to draw the prompt. Renders a
two-line boxed prompt: cwd (via `rtab`), an emoji tag when inside a Python venv
(🐍) or nested conda env (🐉), then user@host on the closing
line (color-coded: cyan normal, green over SSH, red as root). Also defines a
`fish_prompt`-adjacent `on_exit` hook that deactivates any active Python venv when
the shell exits. Widens/narrows automatically to fit terminal width, dropping
user/host first if the line won't fit.

## `fish_user_key_bindings`
Fish's designated hook for custom key bindings — called automatically on shell
init. Here it just delegates to `fzf_key_bindings` if fzf's bindings are loaded.

## `fzf_key_bindings`
Not part of this repo — a symlink installed by Homebrew's `fzf` formula
(`/usr/local/opt/fzf/shell/key-bindings.fish` or the `/opt/homebrew` equivalent on
Apple Silicon) providing fzf's Ctrl-R (history search) and Ctrl-T (file search)
bindings. Present here only because fish's function autoloading requires it to
live in this directory; do not edit directly, it'll be overwritten on fzf
upgrades.

## `run-translate`
```
run-translate input.pdf output.pdf [--lang EN] [--txt]
```
Translates a PDF via the DeepL API (see [`utility/translate_pdf.py`](../../utility/translate_pdf.py)).
On first run, creates a Python venv at `utility/deepl-env/`, installs
dependencies, and prompts for a DeepL API key (saved into the venv's own
`activate-deepl.fish` so it's only set while that venv is active). Detects
Free vs. Pro plan automatically. Sources the venv's activate/deactivate scripts
around the translation call so your shell's Python environment is untouched
afterward. The activate/deactivate scripts it sources live inside the
generated venv (`utility/deepl-env/bin/`), not in this directory — an earlier
pair of reference copies (`activate-deepl.fish`/`deactivate-deepl.fish`) used
to sit here too, but they were dead weight (and a footgun: since neither
wrapped its body in a matching `function ... end`, fish's autoloader would run
their top-level `PATH`/`VIRTUAL_ENV`/prompt-mutating code if you ever typed
their name directly, then report "Unknown command" as if nothing happened),
so they've been removed.
