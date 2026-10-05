{ pkgs, ... }:
{
  toua = {
    # No profiles: this machine intentionally gets only its system config.
  };

  networking.hostName = "sokka";

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;

    initrd.availableKernelModules = [
      # keep-sorted start
      "usb_storage"
      "usbhid"
      "xhci_pci"
      # keep-sorted end
    ];

    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  hardware.enableRedistributableFirmware = true;
}
