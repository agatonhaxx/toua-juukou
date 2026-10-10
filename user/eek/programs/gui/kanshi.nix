{
  lib,
  config,
  pkgs,
  ...
}:
let
  # Same gate as niri.nix. kanshi drives niri's outputs, so it is only
  # meaningful — and only packaged — on a Linux host running niri.
  niriEnabled = pkgs.stdenv.hostPlatform.isLinux && config.wayland.windowManager.niri.enable;
in
{
  # niri's output configuration: kanshi activates only the profile whose outputs
  # are connected, so this one config covers every host; names come from niri.
  services.kanshi = lib.mkIf niriEnabled {
    enable = true;

    settings = [
      {
        profile = {
          name = "baymax-dual";
          outputs = [
            {
              # Philips 346B1C ultrawide, left, at its preferred mode.
              criteria = "Philips Consumer Electronics Company PHL 346B1C *";
              position = "0,0";
              scale = 1.0;
            }
            {
              # Samsung 4K TV, right, at 1.5 scale (2560x1440 logical). The mode
              # is spelled out because the TV prefers 3840x2160@30 on its own.
              criteria = "Samsung Electric Company SAMSUNG *";
              mode = "3840x2160@60Hz";
              position = "3440,0";
              scale = 1.5;
            }
          ];
        };
      }

      {
        profile = {
          name = "baymax-ultrawide";
          outputs = [
            {
              criteria = "Philips Consumer Electronics Company PHL 346B1C *";
              position = "0,0";
              scale = 1.0;
            }
          ];
        };
      }

      {
        profile = {
          name = "bender-dual";
          outputs = [
            {
              criteria = "HDMI-A-2";
              position = "2560,0";
              scale = 1.0;
            }
            {
              criteria = "eDP-1";
              position = "0,0";
              scale = 1.0;
            }
          ];
        };
      }

      {
        profile = {
          name = "bender-laptop";
          outputs = [
            {
              criteria = "eDP-1";
              position = "0,0";
              scale = 1.0;
            }
          ];
        };
      }
    ];
  };
}
