{ lib, ... }:
{
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  boot = {
    kernelModules = [
      "kvm-amd"
      "amdgpu"
    ];

    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "ahci"
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];
  };

  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-id/nvme-PNY_CS3030_1TB_SSD_PNY0720003924010E05B-part2";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
      "subvol=/root"
    ];
  };

  fileSystems."/home" = lib.mkForce {
    device = "/dev/disk/by-id/nvme-PNY_CS3030_1TB_SSD_PNY0720003924010E05B-part2";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
      "subvol=/home"
    ];
  };

  fileSystems."/nix" = lib.mkForce {
    device = "/dev/disk/by-id/nvme-PNY_CS3030_1TB_SSD_PNY0720003924010E05B-part2";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
      "subvol=/nix"
    ];
  };

  fileSystems."/snapshots" = lib.mkForce {
    device = "/dev/disk/by-id/nvme-PNY_CS3030_1TB_SSD_PNY0720003924010E05B-part2";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
      "subvol=/snapshots"
    ];
  };

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-id/nvme-PNY_CS3030_1TB_SSD_PNY0720003924010E05B-part1";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  fileSystems."/data/baymax" = {
    device = "/dev/mapper/data-baymax";
    fsType = "xfs";
    options = [ "noatime" ];
  };

  # Nested inside the xfs volume above. systemd orders a nested mount after its
  # parent on its own, so ordering is not what this entry has to get right.
  #
  # There is deliberately no `subvol=` here: `btrfs subvolume list` on this
  # filesystem is empty — autobrr, sonarr, qbittorrent and the rest all live in
  # the top-level tree, and the default subvolume is FS_TREE. The `subvol=qt`
  # this entry used to carry (taken from the volume's *label*) named nothing,
  # so mount failed with `fsconfig() failed: No such file or directory` and
  # local-fs.target dropped the machine into an emergency shell every time.
  #
  # `nofail` so a media volume can never do that again.
  fileSystems."/data/baymax/qt" = {
    device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_500GB_S466NX0K927369W-part1";
    fsType = "btrfs";
    options = [ "compress=zstd" "noatime" "nofail" ];
  };

  # Nothing created this file but the installer once did: nixpkgs generates the
  # unit that makes a swap device only for entries carrying a `size` (or using
  # random encryption), so this pointed at a file that was not there. `/var` is
  # on btrfs, and a size routes creation through `btrfs filesystem mkswapfile`,
  # which also sets nocow and turns compression off for the file, as a btrfs
  # swapfile requires. 16 GiB for 31 GiB of RAM, headroom rather than a resume
  # target: no hibernation is configured, and a btrfs swapfile would need a
  # `resume_offset` for that anyway.
  swapDevices = [ { device = "/var/swapfile"; size = 16384; } ];
}
