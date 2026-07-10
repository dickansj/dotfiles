# finds Homebrew formulae in the Brewfile that are keg-only (not
#   auto-linked into /opt/homebrew/bin because macOS ships its own version,
#   or to avoid clobbering a manually-managed toolchain) and provide real
#   CLI binaries, but have no matching entry in path.fish - the exact bug
#   found and fixed five times in one session (python, ruby, rustup,
#   sqlite, trash) before this script existed.

import json
import os
import re
import subprocess

os.chdir(os.path.dirname(os.path.abspath(__file__)))

# formulae that are keg-only, do provide CLI binaries, but are deliberately
#   NOT meant to be on PATH - handled some other way instead
KNOWN_EXCEPTIONS = {
    # exposed via the JVM symlink in provision-mac.sh
    #   (/Library/Java/JavaVirtualMachines/), not PATH
    "openjdk",
}


def brewfile_formulas():
    names = []
    with open("../install_lists/Brewfile", "r") as f:
        for line in f:
            line = line.strip()
            if not line.startswith("brew '") and not line.startswith('brew "'):
                continue
            token = line.split()[1]
            if token.endswith(","):
                token = token[:-1]
            names.append(token[1:-1])
    return names


def path_fish_targets():
    with open("../fish.configlink/path.fish", "r") as f:
        content = f.read()
    return set(re.findall(r"/opt/homebrew/opt/([^/\s\"']+)", content))


def has_cli_binaries(formula):
    bin_dir = f"/opt/homebrew/opt/{formula}/bin"
    return os.path.isdir(bin_dir) and len(os.listdir(bin_dir)) > 0


def main():
    formulas = brewfile_formulas()
    tracked = path_fish_targets()

    result = subprocess.run(
        ["brew", "info", "--json=v2"] + formulas,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("Could not query brew info - is everything in the Brewfile installed?")
        print(result.stderr.strip())
        return

    data = json.loads(result.stdout)

    gaps = []
    for f in data["formulae"]:
        name = f["name"]
        if not f.get("keg_only"):
            continue
        if name in KNOWN_EXCEPTIONS:
            continue
        if not has_cli_binaries(name):
            continue
        if name not in tracked:
            gaps.append(name)

    if gaps:
        print("Keg-only formulae with CLI binaries missing from path.fish:")
        for name in sorted(gaps):
            print(f"  {name}  (add: set -a myPath /opt/homebrew/opt/{name}/bin)")
    else:
        print("All keg-only formulae with CLI binaries are on PATH.")


main()
