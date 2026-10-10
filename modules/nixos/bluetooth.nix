{
  config,
  lib,
  ...
}:
let
  cfg = config.toua.programs;
in
{
  # `hardware.bluetooth` and `services.blueman` are system options, so unlike
  # the rest of `toua.programs` they cannot live in the Home Manager modules.
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
