#!/bin/bash

# make sure we're in the right place...
cd "$(dirname "$0")"
LOCAL_ROOT=$(pwd -P)

source ../../utility/utility_functions.sh
overwrite_all=false backup_all=false skip_all=false

## Destinations
supportDir="$HOME/Library/Application Support/BBEdit/Setup"

## Make dest folders if they don't exist
mkdir -p "$supportDir"

## Symlink BBEdit config files
link_file "$LOCAL_ROOT/Grep Patterns.xml" "$supportDir/Grep Patterns.xml"
link_file "$LOCAL_ROOT/Menu Shortcuts.plist" "$supportDir/Menu Shortcuts.plist"