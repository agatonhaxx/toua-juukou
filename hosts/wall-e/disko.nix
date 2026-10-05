{
  # wall-e boots via UEFI: 64-bit firmware on a KVM guest, confirmed on the box.
  # The stock Hetzner image carries no NVRAM boot entry — the firmware reaches
  # its bootloader through the removable fallback path `/EFI/BOOT/BOOTX64.EFI`,
  # which is what the installer writes when `canTouchEfiVariables` is left off.
  # See the `boot.loader` block in ./default.nix for the other half of this.
  #
  # The ESP is mounted at `/boot` rather than `/boot/efi` because systemd-boot
  # has no filesystem drivers: it can only load what sits on the ESP itself, so
  # a kernel left in `/nix/store` is out of its reach. Every generation therefore
  # puts a kernel and initrd on this partition, and the 2G is sized for that —
  # `boot.loader.systemd-boot.configurationLimit` bounds the growth.
  #
  # nixos-anywhere wipes whatever this points at.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda";

    content = {
      type = "gpt";

      partitions = {
        esp = {
          size = "2G";
          type = "EF00";

          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };

        root = {
          size = "100%";

          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
