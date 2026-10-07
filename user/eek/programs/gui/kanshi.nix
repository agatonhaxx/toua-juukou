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
  # kanshi is niri's own answer to output configuration (niri's FAQ points at
  # it, and niri implements the `zwlr_output_manager_v1` protocol it speaks).
  #
  # It activates the profile whose outputs are all *connected* and which
  # matches the most of them, so the profiles below are the detection: the
  # ultrawide-and-TV pair on baymax, the laptop-and-TV pair on bender, and the
  # single-monitor fallback for each. Because a profile for the other machine
  # names outputs that are not connected, it never activates — one shared
  # config covers both hosts.
  #
  # This replaces the static `output` blocks that used to sit in
  # niri/config.kdl. Those named bender's connectors on every host, so baymax
  # (DP-3 + HDMI-A-1) was never actually configured by nix.
  #
  # baymax's criteria are the "manufacturer model serial" strings reported by
  # `niri msg outputs`, globbed so they survive a serial going missing. They
  # are stable across reboots and re-cabling, unlike connector names, which the
  # kernel is free to renumber. bender's two outputs keep their connector names
  # because that is all the old static blocks recorded.
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
              # Samsung 4K TV, right. Scale 1.5 puts it at 2560x1440 logical,
              # which is what its size and viewing distance want. The mode is
              # spelled out because the TV prefers 3840x2160@30 and will pick
              # it on its own; @60 is in its EDID.
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
