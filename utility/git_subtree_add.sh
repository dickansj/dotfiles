#!/usr/bin/env zsh

SRC_DIR=$(cd "$(dirname "$0")"; pwd)

if [[ $# -lt 2 ]]; then
  echo "Usage: git_subtree_add.sh [URL] [LOCAL_PATH]"
  exit 1
fi

url="$1"
if [[ ${url:0:14} = "git@github.com" ]] || [[ ${url:0:18} = "https://github.com" ]]; then
  name="${url%.git}"
  name="${name##*/}"
else
  echo "ERROR: Couldn't parse URL. Do this manually."
  exit 1
fi
name=$name:l

default_branch=$(git ls-remote --symref $url HEAD | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2}')
if [[ -z $default_branch ]]; then
  echo "ERROR: Couldn't detect default branch for $url. Do this manually."
  exit 1
fi

cd "$SRC_DIR/.."
git subtree add --prefix=$2 --squash $url $default_branch
cd "$SRC_DIR"
echo "$name	$url	$2" >> git_subtrees.txt
