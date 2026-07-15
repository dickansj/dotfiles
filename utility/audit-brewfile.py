# processes the brewfile and checks it against the public Homebrew API
#   to see if any of the formulae have been dropped.


import os
import sys
import json
import http.client
import re
import time

os.chdir(os.path.dirname(os.path.abspath(__file__)))

brewfile_contents = open("../install_lists/Brewfile", "r").read()

# patterns for things to allow if they're not found in the list (for taps and things)
#   could get fancy and try to follow the taps and see if they're there, but ain't
#   nobody got time for that and I only use a few non-standard taps.
#   NB these are regex prefixes (re.match), not globs - an earlier version
#   wrote them glob-style ('^font-*'), where the * quantified the preceding
#   character and matched more than intended. font-* is gone entirely:
#   homebrew/cask-fonts merged into the main cask API in 2024, so fonts get
#   audited for real now.
allow = [
    r"^sjml/sjml/",
    r"^rcmdnk/file/",
    r"^melonamin/formulae/",
    r"^ttscoff/thelab/",
    r"^updatest@",
]

brews = []
casks = []
mapps = []

for line in brewfile_contents.splitlines():
    line = line.strip()
    if len(line) == 0 or line[0] == "#":
        continue
    elements = line.split()
    if elements[0] == "brew":
        if elements[1].endswith(","):
            elements[1] = elements[1][:-1]
        brews.append(elements[1][1:-1])
    elif elements[0] == "cask":
        if elements[1].endswith(","):
            elements[1] = elements[1][:-1]
        casks.append(elements[1][1:-1])
    elif elements[0] == "mas":
        id = elements[-1]
        app_name = re.findall(r"^mas\s'([^']*)'", line)[0]
        mapps.append([app_name, id])
    else:
        pass
        # print("skipping", elements[0])


def get_url(server, url):
    hc = http.client.HTTPSConnection(server)
    hc.request("GET", url)
    resp = hc.getresponse()
    code = resp.getcode()
    if code != 200:
        raise RuntimeError(f"Could not load remote URL: {url}, status code {code}")
    return resp.read().decode("utf-8")

# a week: fresh enough to catch renames/removals, without re-downloading
#   ~30MB of catalog on every run. Delete the cached files to force a
#   fresh fetch sooner.
MAX_CACHE_AGE = 7 * 24 * 60 * 60

def get_catalog(path, url):
    stale = (
        not os.path.exists(path)
        or time.time() - os.path.getmtime(path) > MAX_CACHE_AGE
    )
    if stale:
        data = get_url("formulae.brew.sh", url)
        with open(path, "w") as fout:
            fout.write(data)
    else:
        with open(path, "r") as fin:
            data = fin.read()
    return data

formulae_json = get_catalog("./formula.json", "/api/formula.json")
cask_json = get_catalog("./cask.json", "/api/cask.json")

formula_list = set()
for f in json.loads(formulae_json):
    formula_list.add(f['name'])
    formula_list.update(f.get('aliases') or [])
    formula_list.update(f.get('oldnames') or [])

cask_list = set()
for c in json.loads(cask_json):
    cask_list.add(c['token'])
    cask_list.update(c.get('old_tokens') or [])

print(f"🕵️  Checking Brewfile with {len(brews)} formulae and {len(casks)} casks...")

errs = []

def check_allowed(string):
    for r in allow:
        if re.match(r, string):
            return True
    return False

for b in brews:
    if b not in formula_list and not check_allowed(b):
        errs.append(["brew", b])
for c in casks:
    if c not in cask_list and not check_allowed(c):
        errs.append(["cask", c])

print(f"🕵️  Checking {len(mapps)} app listings against the Mac App Store...")
for a in mapps:
    results_json = get_url("itunes.apple.com", f"/lookup?id={a[1]}")
    results = json.loads(results_json)
    if results['resultCount'] == 0:
        errs.append(["mas", a[0]])

print()
if len(errs) == 0:
    print("🎉  Brewfile is legit!")
else:
    print("🙈  Brewfile's got issues.")
    for e in errs:
        print(f"❌  {e[0]} {e[1]}")
    sys.exit(len(errs))
