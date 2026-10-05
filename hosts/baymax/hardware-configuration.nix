{ lib, ... }:
{
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  boot = {
    kernelModules = [
      "kvm-amd"
      "amdgpu"
    ];

    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };

      # Spelled out because the default has moved between nixpkgs releases and this
      # one has to agree with the mountpoint in ./disko.nix.
      efi.efiSysMountPoint = "/boot";
    };

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

  swapDevices = [ { device = "/var/swapfile"; } ];
}
