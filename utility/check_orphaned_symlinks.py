# checks symlinked dotfiles that configure an optional external tool
#   against whether that tool is actually installed - same failure mode as
#   devbox_no_prompt/condarc.symlink, both removed this session after being
#   found by hand. There's no mechanical way to derive "this file configures
#   that tool" from the filename alone, so this is a manually maintained
#   registry - add an entry here whenever a new symlink is added for an
#   optional (not always-present) external tool.

import shutil

REGISTRY = {
    "hgrc.symlink": "hg",
    "yt-dlp.symlink": "yt-dlp",
    "paper_meta.yml.symlink": "paper",
}


def main():
    orphaned = []
    for symlink, command in REGISTRY.items():
        if shutil.which(command) is None:
            orphaned.append((symlink, command))

    if orphaned:
        print("Symlinked config for tools that aren't installed:")
        for symlink, command in orphaned:
            print(f"  {symlink} (configures `{command}`, not found on PATH)")
    else:
        print("Every registered symlink's tool is installed.")


main()
