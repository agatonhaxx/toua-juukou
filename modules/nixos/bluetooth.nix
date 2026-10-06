{
  config,
  lib,
  ...
}:
let
  cfg = config.toua.programs;
in
{
  # `hardware.bluetooth` starts the bluez daemon; `services.blueman` puts the
  # applet in systemPackages, dbus.packages and systemd.packages. Both are
  # system options that exist on NixOS only, so unlike the other `toua.programs`
  # entries these cannot be implemented from `modules/programs/`, which Home
  # Manager loads.
  #
  # bender sets `hardware.bluetooth` directly and leaves the toggle at its
  # default, so nothing here is defined for it.
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.blueman.enable || cfg.bluetooth.enable;
          message = "toua.programs.blueman.enable requires toua.programs.bluetooth.enable — the applet has no daemon otherwise";
        }
      ];
    }

    (lib.mkIf cfg.bluetooth.enable {
      hardware.bluetooth.enable = true;
    })

    (lib.mkIf cfg.blueman.enable {
      services.blueman.enable = true;
    })
  ];
}
