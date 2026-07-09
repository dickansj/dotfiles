#!/usr/bin/env zsh

SRC_DIR=$(cd "$(dirname "$0")"; pwd)

while read data; do
  local name=$data[(w)1]
  local url=$data[(w)2]

  git remote add $name $url
done <"$SRC_DIR/git_subtrees.txt"
