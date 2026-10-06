# Baymax Installation

This procedure installs Baymax locally from a NixOS installer USB. It does not
use kexec, SSH, or `nixos-anywhere`.

## Before You Start

- Boot the NixOS installer in UEFI mode and connect it to the network.
- Make this repository available on the installer and `cd` to its root. The
  `path:` flake reference below uses the current working tree, including local
  changes.
- Back up anything needed from the system disk. The install repartitions and
  formats the configured PNY NVMe.
- Confirm the disk identity before continuing. Do not proceed if the model or
  serial does not match Baymax's PNY system disk.

```sh
disk=/dev/disk/by-id/nvme-PNY_CS3030_1TB_SSD_PNY0720003924010E05B
lsblk -o NAME,SIZE,MODEL,SERIAL,MOUNTPOINTS
readlink -f "$disk"
```

## Install (Erases the System Disk)

`hosts/baymax/disko.nix` declares the layout disko writes: a 2 GiB FAT32 EFI
partition mounted at `/boot`, and one Btrfs partition carrying the `root`,
`home`, `nix`, and `snapshots` subvolumes, each mounted with `compress=zstd` and
`noatime`. The data disks, including `/data/baymax`, are not in the disko target
and are left untouched; they are declared in `hardware-configuration.nix`.

From the repository devshell on the installer, partition, format, and mount the
result under `/mnt`:

```sh
sudo disko --mode disko hosts/baymax/disko.nix
```

`sudo` may drop the devshell from `PATH`; if it cannot find `disko`, use the path
printed by `command -v disko` instead. `--mode disko` is short for
`--mode destroy,format,mount`, and it is the only step that writes to the disk.

Then install NixOS into the mounted system:

```sh
sudo nixos-install --flake path:.#baymax
```

No disk passphrase or TPM enrollment is required.

## Reinstalling Over an Existing Layout

If the PNY disk already has the layout above and only NixOS needs reinstalling,
mount it without touching the partitions:

```sh
sudo disko --mode mount hosts/baymax/disko.nix
sudo nixos-install --flake path:.#baymax
```

Do not rerun `--mode disko` to retry a failed install; it erases the disk again.
