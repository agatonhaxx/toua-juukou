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

  # Nested inside the xfs volume above, so it must not mount until that one
  # has: systemd otherwise mounts the two in parallel and the xfs can land on
  # top of the nvme, hiding it. `depends` is what becomes the mount unit's
  # `x-systemd.requires-mounts-for`.
  #
  # `subvol=qt` is what the partition was mounted with before this entry was
  # lost: the btrfs root is not the data, so without it the mount succeeds and
  # shows a single empty directory named `qt` in place of the contents.
  # `compress=zstd` was on it too.
  fileSystems."/data/baymax/qt" = {
    device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_500GB_S466NX0K927369W-part1";
    fsType = "btrfs";
    options = [ "compress=zstd" "noatime" "subvol=qt" ];
    depends = [ "/data/baymax" ];
  };

  swapDevices = [ { device = "/var/swapfile"; } ];
}
