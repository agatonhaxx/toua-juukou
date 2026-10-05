#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

for mount_path in /mnt /mnt/boot; do
  if ! mountpoint -q "$mount_path"; then
    printf 'Missing mount: %s. Run mount-existing.sh first.\n' "$mount_path" >&2
    exit 1
  fi
done

sudo nixos-install --flake "path:$PWD#baymax" --root /mnt