{
  # The GNOME desktop, GDM, the niri session registration and the shared
  # session plumbing (X11, PipeWire) are not configured here — they follow
  # `toua.desktop.*` / `toua.displayManager.*` in `modules/nixos/desktop.nix`,
  # and bender turns them on by setting its profile to "desktop".
  #
  # What is left is what is specific to this machine: its lid, its Bluetooth
  # radio, and the SSH daemon that supplies the host key sops derives its age
  # identity from.
  services = {
    # Keep running when lid is closed (laptop docked to TV)
    logind = {
      settings = {
        Login = {
          HandleLidSwitch = "ignore";
          HandleLidSwitchExternalPower = "ignore";
          HandleLidSwitchDocked = "ignore";
        };
      };
    };

    # Disable internal keyboard/touchpad when lid is closed
    acpid = {
      enable = true;
      handlers = {
        lid-close = {
          event = "button/lid LID close";
          action = ''
            for dev in /sys/devices/platform/i8042/serio0/input/input*/inhibited; do
              echo 1 > "$dev" 2>/dev/null || true
            done
            for dev in /sys/devices/platform/i8042/serio1/input/input*/inhibited; do
              echo 1 > "$dev" 2>/dev/null || true
            done
          '';
        };
        lid-open = {
          event = "button/lid LID open";
          action = ''
            for dev in /sys/devices/platform/i8042/serio0/input/input*/inhibited; do
              echo 0 > "$dev" 2>/dev/null || true
            done
            for dev in /sys/devices/platform/i8042/serio1/input/input*/inhibited; do
              echo 0 > "$dev" 2>/dev/null || true
            done
          '';
        };
      };
    };

    # Tray applet for the Bluetooth radio enabled in default.nix.
    blueman.enable = true;

    openssh = {
      generateHostKeys = true;
      enable = true;
      settings = {
        ListenAddress = "0.0.0.0";
        PubkeyAuthentication = true;
        PermitEmptyPasswords = false;
      };
    };
  };
}
