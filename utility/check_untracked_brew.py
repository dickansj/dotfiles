# finds formulae/casks actually installed (via `brew install`) that never
#   made it into the Brewfile - the mirror of audit-brewfile.py, which
#   checks the other direction (Brewfile entries that no longer exist
#   upstream). Reuses audit-brewfile.py's alias/old_tokens lookups so a
#   cask or formula tracked under an old name isn't flagged as untracked.

import json
import os
import subprocess
import urllib.request

os.chdir(os.path.dirname(os.path.abspath(__file__)))


def get_json(path, url):
    if not os.path.exists(path):
        with urllib.request.urlopen(url) as resp:
            data = resp.read().decode("utf-8")
        with open(path, "w") as fout:
            fout.write(data)
    else:
        with open(path, "r") as fin:
            data = fin.read()
    return json.loads(data)


def tracked_names(keyword):
    names = set()
    with open("../install_lists/Brewfile", "r") as f:
        for line in f:
            line = line.strip()
            if not line.startswith(f"{keyword} '") and not line.startswith(f'{keyword} "'):
                continue
            token = line.split()[1]
            if token.endswith(","):
                token = token[:-1]
            token = token[1:-1]
            names.add(token)
            # tap-qualified entries (e.g. "sjml/sjml/beschi") install and
            #   list under just their short name ("beschi"), not the full
            #   tap path - track both so they're recognized either way
            if "/" in token:
                names.add(token.rsplit("/", 1)[-1])
    return names


def installed(cmd):
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    return sorted(line for line in out.splitlines() if line.strip())


tracked_formulae = tracked_names("brew")
tracked_casks = tracked_names("cask")

formula_data = get_json("formula.json", "https://formulae.brew.sh/api/formula.json")
cask_data = get_json("cask.json", "https://formulae.brew.sh/api/cask.json")

formula_by_name = {f["name"]: f for f in formula_data}
cask_by_token = {c["token"]: c for c in cask_data}

print("Formulae not in Brewfile:")
for name in installed(["brew", "leaves"]):
    f = formula_by_name.get(name)
    names = {name}
    if f:
        names |= set(f.get("aliases") or [])
        names |= set(f.get("oldnames") or [])
    if not (names & tracked_formulae):
        print(f"  {name}")

print()
print("Casks not in Brewfile:")
for token in installed(["brew", "list", "--cask"]):
    c = cask_by_token.get(token)
    names = {token}
    if c:
        names |= set(c.get("old_tokens") or [])
    if not (names & tracked_casks):
        print(f"  {token}")
