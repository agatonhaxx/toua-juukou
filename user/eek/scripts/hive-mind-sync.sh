#!/usr/bin/env bash

usage() {
    cat <<EOF
hive-mind-sync - clone or update the hive-mind notebook

usage: hive-mind-sync

Clones the notebook when it is missing and fast-forwards it otherwise.
The notebook is always stored at ~/dev/eek/hive-mind, which is where
user/programs/zk.nix points zk.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -ne 0 ]]; then
    usage >&2
    exit 2
fi

repo="git@github.com:agatonhaxx/hive-mind.git"
dest="$HOME/dev/eek/hive-mind"

if [[ -d "$dest/.git" ]]; then
    git -C "$dest" pull --ff-only
elif [[ -e "$dest" ]]; then
    echo "hive-mind-sync: $dest exists but is not a git repository" >&2
    exit 1
else
    mkdir -p "$(dirname "$dest")"
    git clone "$repo" "$dest"
fi
