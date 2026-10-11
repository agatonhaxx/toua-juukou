#!/usr/bin/env bash
# Run borg the way one backup job runs it: borg-job personal list --last 3
#
# The repository, the SSH identity and the passphrase command all come from the
# job's own systemd unit, so nothing here restates a path that
# modules/nixos/services/borgbackup.nix sets — and borg is the exact build that
# wrote the archive rather than whatever else is on PATH.

unit="borgbackup-job-$1"
shift

if [ "$(systemctl show "$unit" -p LoadState --value)" != loaded ]; then
  echo "$unit is not a unit on this host" >&2
  exit 1
fi

# systemd prints a unit's environment as NAME=value pairs, quoted the way a
# shell quotes them, so the line can be sourced as it stands.
eval "export $(systemctl show "$unit" -p Environment --value)"
PATH="$PATH:/run/current-system/sw/bin" # adds sudo; the job's borg stays first
borg_bin=$(command -v borg)

# /run/secrets is root-only, which is why borg runs as root, and why the
# variables are handed over with `env`: --preserve-env needs a SETENV rule this
# sudoers does not grant.
exec sudo env BORG_REPO="$BORG_REPO" BORG_RSH="$BORG_RSH" \
  BORG_PASSCOMMAND="$BORG_PASSCOMMAND" BORG_RELOCATED_REPO_ACCESS_IS_OK=yes \
  "$borg_bin" "$@"
