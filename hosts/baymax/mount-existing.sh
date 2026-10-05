#!/usr/bin/env bash
set -euo pipefail

disk=/dev/disk/by-id/nvme-PNY_CS3030_1TB_SSD_PNY0720003924010E05B
root_partition="${disk}-part2"
efi_partition="${disk}-part1"

if [ "$(sudo blkid -s TYPE -o value "$root_partition")" != btrfs ] ||
  [ "$(sudo blkid -s TYPE -o value "$efi_partition")" != vfat ]; then
  printf 'Expected unencrypted Btrfs on partition 2 and FAT on partition 1. Check lsblk -f.\n' >&2
  exit 1
fi

if mountpoint -q /mnt; then
  printf '/mnt is already mounted. Inspect findmnt -R /mnt before proceeding.\n' >&2
  exit 1
fi

sudo mkdir -p /mnt
sudo mount -t btrfs -o subvol=/root,compress=zstd,noatime "$root_partition" /mnt

for subvolume in home nix snapshots; do
  sudo mkdir -p "/mnt/$subvolume"
  sudo mount -t btrfs -o "subvol=/$subvolume,compress=zstd,noatime" \
    "$root_partition" "/mnt/$subvolume"
done

sudo mkdir -p /mnt/boot
sudo mount -t vfat -o umask=0077 "$efi_partition" /mnt/boot