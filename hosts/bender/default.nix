{ inputs, ... }:
{
  imports = [
    ../../user
    ./services.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-yoga
  ];

  toua = {
    profiles.desktop.enable = true;
    primaryUser = "eek";
    users.eek.homeModule = ../../user/eek;

  };

  networking = {
    hostName = "bender";
    wireless.enable = true;
    networkmanager.enable = true;
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd = {
      availableKernelModules = [
        # keep-sorted start
        "nvme"
        "rtsx_pci_sdmmc"
        "sd_mod"
        "usb_storage"
        "xhci_pci"
        # keep-sorted end
      ];
      kernelModules = [ ];
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/0b6c524c-41e8-4efd-82cc-736907ff68e4";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CF2A-75CC";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/51dd3dfc-eb7d-4dd1-a1a1-39544eab34da"; } ];

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
  powerManagement.cpuFreqGovernor = "ondemand";

}
