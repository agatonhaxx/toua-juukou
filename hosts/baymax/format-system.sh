#!/usr/bin/env bash
set -euo pipefail

disk=/dev/disk/by-id/nvme-PNY_CS3030_1TB_SSD_PNY0720003924010E05B
serial=PNY0720003924010E05B
efi_partition="${disk}-part1"
root_partition="${disk}-part2"

if [ "$(uname -s)" != Linux ] || [ "$EUID" -ne 0 ]; then
  printf 'Run with sudo bash on the NixOS USB installer.\n' >&2
  exit 1
fi

for tool in lsblk grep sgdisk wipefs partprobe udevadm mkfs.fat mkfs.btrfs \
  btrfs mktemp mount mountpoint umount rmdir; do
  if ! command -v "$tool" >/dev/null; then
    printf 'Required command not found: %s\n' "$tool" >&2
    exit 1
  fi
done

if [ ! -b "$disk" ] || [ "$(lsblk -dnro SERIAL "$disk")" != "$serial" ]; then
  printf 'PNY system disk not found or its serial does not match. Nothing changed.\n' >&2
  exit 1
fi

lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,FSTYPE,MOUNTPOINTS "$disk"

mounts=$(lsblk -nro MOUNTPOINTS "$disk")
types=$(lsblk -nro TYPE "$disk")
if printf '%s\n' "$mounts" | grep -q '[^[:space:]]' ||
  printf '%s\n' "$types" | grep -qEv '^(disk|part)$'; then
  printf 'Disk is in use. Unmount its filesystems, disable its swap, and close its active mappings first.\n' >&2
  exit 1
fi

if [ "$(lsblk -dnro RO "$disk")" != 0 ]; then
  printf 'Disk is read-only. Nothing changed.\n' >&2
  exit 1
fi

printf '\nWARNING: This erases the ENTIRE PNY system disk, including encrypted data.\n'
printf 'Other disks will not be formatted.\n'
read -r -p "Type $serial to erase this disk: " confirmation < /dev/tty
if [ "$confirmation" != "$serial" ]; then
  printf 'Cancelled. Nothing changed.\n' >&2
  exit 1
fi

sgdisk --zap-all "$disk"
sgdisk --clear \
  --new=1:0:+2G --typecode=1:ef00 --change-name=1:ESP \
  --new=2:0:0 --typecode=2:8300 --change-name=2:root \
  "$disk"
partprobe "$disk"
udevadm settle

if [ ! -b "$efi_partition" ] || [ ! -b "$root_partition" ]; then
  printf 'Partition device paths are missing. Stop and inspect lsblk before retrying.\n' >&2
  exit 1
fi

wipefs --all "$efi_partition" "$root_partition"
mkfs.fat -F 32 -n BAYMAX_EFI "$efi_partition"
mkfs.btrfs -f -L BAYMAX_ROOT "$root_partition"

mount_dir=$(mktemp -d /tmp/baymax-btrfs.XXXXXX)
cleanup() {
  if mountpoint -q "$mount_dir"; then
    umount "$mount_dir" || return
  fi
  rmdir "$mount_dir"
}
trap cleanup EXIT

mount -t btrfs -o subvolid=5 "$root_partition" "$mount_dir"
for subvolume in root home nix snapshots; do
  btrfs subvolume create "$mount_dir/$subvolume"
done

printf '\nFormatting complete. Next run:\n'
printf 'bash hosts/baymax/mount-existing.sh\n'
printf 'bash hosts/baymax/install-existing.sh\n'