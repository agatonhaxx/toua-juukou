# Baymax Installation

This procedure installs Baymax locally from a NixOS installer USB. It does not
use kexec or SSH.

## Before You Start

- Boot the NixOS installer in UEFI mode and connect it to the network.
- Make this repository available on the installer and `cd` to its root. The
  `path:` flake reference below uses the current working tree, including local
  changes.
- Back up anything needed from the system disk. The fresh-install workflows
  repartition and format the configured PNY NVMe; the reuse workflow does not.
- Confirm the disk identity before continuing. Do not proceed if the model or
  serial does not match Baymax's PNY system disk.

```sh
disk=/dev/disk/by-id/nvme-PNY_CS3030_1TB_SSD_PNY0720003924010E05B
lsblk -o NAME,SIZE,MODEL,SERIAL,MOUNTPOINTS
readlink -f "$disk"
```

## Reuse Existing Partitions

Use this only if the PNY system disk already has the unencrypted Btrfs layout
defined in `hardware-configuration.nix`, including its subvolumes and EFI partition. Check `lsblk -f`
first: Btrfs must be directly on the root partition, not inside `crypto_LUKS`.
Mounting does not convert an encrypted layout. Run from the repository root.

Mount the existing filesystems without formatting:

```sh
bash hosts/baymax/mount-existing.sh
```

After mounting succeeds, install NixOS into `/mnt` without repartitioning:

```sh
bash hosts/baymax/install-existing.sh
```

Both commands work from Bash or Fish. The mount script uses ordinary `mount`
commands, not Disko or Nix. It checks for Btrfs on PNY partition 2 and FAT on
partition 1, then mounts `/`, `/home`, `/nix`, `/snapshots`, and `/boot` under
`/mnt`. If `/mnt` is already mounted, inspect `findmnt -R /mnt` before proceeding.
The install script locates the repository root automatically and refuses to
continue unless `/mnt` and `/mnt/boot` are mounted. Neither script formats disks.
The existing data mounts, including `/data/baymax/qt`, remain unchanged.

## Fresh Install (Erases System Disk)

Use this when the system partition is still encrypted or the required Btrfs
layout does not exist. Back up anything needed first. Run from the repository
root on Baymax's NixOS USB installer:

```sh
sudo bash hosts/baymax/format-system.sh
```

This erases the entire PNY system NVMe, including its encrypted contents. The
script checks the disk serial and refuses to proceed with mounted filesystems,
active swap, or active mappings on that disk. Unmount and close those first if
it refuses. It requires typing `PNY0720003924010E05B` before erasing anything.
It does not use Disko or Nix and does not format the data disks.

It creates a GPT with a 2 GiB FAT32 EFI partition and an unencrypted Btrfs
partition using the remaining space. The Btrfs subvolumes are `root`, `home`,
`nix`, and `snapshots`, matching `hardware-configuration.nix`.

Once formatting succeeds, mount it:

```sh
bash hosts/baymax/mount-existing.sh
```

Once mounting succeeds, install:

```sh
bash hosts/baymax/install-existing.sh
```

Do not rerun the format script to retry installation. Reuse the mount and
install scripts instead. No disk passphrase or TPM enrollment is required.