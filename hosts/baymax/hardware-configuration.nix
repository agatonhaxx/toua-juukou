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

  # Nested inside the xfs volume above; no `subvol=`, because the filesystem has
  # none and the old label-derived `subvol=qt` broke mount — hence `nofail`.
  fileSystems."/data/baymax/qt" = {
    device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_500GB_S466NX0K927369W-part1";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
      "nofail"
    ];
  };

  # Without `size` nixpkgs generates no unit that creates the file, so this once
  # pointed at a missing swapfile; a size routes creation through btrfs mkswapfile.
  swapDevices = [
    {
      device = "/var/swapfile";
      size = 16384;
    }
  ];
}
