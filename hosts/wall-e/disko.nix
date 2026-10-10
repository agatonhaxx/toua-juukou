{
  # UEFI on a KVM guest with no NVRAM entry, so the firmware boots via the
  # removable fallback path; `/boot`, because systemd-boot cannot read /nix/store.

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
